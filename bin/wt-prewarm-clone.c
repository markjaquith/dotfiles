#include <sys/clonefile.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *join_path(const char *root, const char *path, const char *suffix) {
	size_t root_len = strlen(root);
	size_t path_len = strlen(path);
	size_t suffix_len = strlen(suffix);
	char *result = malloc(root_len + path_len + suffix_len + 2);

	if (result == NULL) {
		return NULL;
	}

	memcpy(result, root, root_len);
	result[root_len] = '/';
	memcpy(result + root_len + 1, path, path_len);
	memcpy(result + root_len + path_len + 1, suffix, suffix_len + 1);
	return result;
}

static int unchanged(const struct stat *before, const struct stat *after) {
	return before->st_dev == after->st_dev && before->st_ino == after->st_ino &&
		before->st_size == after->st_size &&
		before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
		before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
		before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
		before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
}

static int compare_paths(const void *left, const void *right) {
	const char *left_path = *(const char *const *)left;
	const char *right_path = *(const char *const *)right;

	return strcmp(left_path, right_path);
}

int main(int argc, char **argv) {
	char *path = NULL;
	size_t path_capacity = 0;
	char **excluded = NULL;
	size_t excluded_count = 0;
	size_t excluded_capacity = 0;
	unsigned long long cloned = 0;
	unsigned long long sequence = 0;

	if (argc != 4) {
		return 2;
	}

	FILE *excluded_file = fopen(argv[3], "r");
	if (excluded_file == NULL) {
		return 3;
	}

	while (getdelim(&path, &path_capacity, '\0', excluded_file) != -1) {
		if (excluded_count == excluded_capacity) {
			size_t next_capacity = excluded_capacity == 0 ? 64 : excluded_capacity * 2;
			char **next = realloc(excluded, next_capacity * sizeof(*excluded));
			if (next == NULL) {
				fclose(excluded_file);
				free(path);
				return 3;
			}
			excluded = next;
			excluded_capacity = next_capacity;
		}

		excluded[excluded_count] = strdup(path);
		if (excluded[excluded_count] == NULL) {
			fclose(excluded_file);
			free(path);
			return 3;
		}
		excluded_count++;
	}
	if (ferror(excluded_file)) {
		fclose(excluded_file);
		free(path);
		return 4;
	}
	fclose(excluded_file);
	qsort(excluded, excluded_count, sizeof(*excluded), compare_paths);

	while (getdelim(&path, &path_capacity, '\0', stdin) != -1) {
		char suffix[80];
		char *source;
		char *target;
		char *temporary;
		struct stat source_before;
		struct stat source_after;
		struct stat target_stat;
		struct stat target_after;
		struct timespec target_times[2];

		if (path[0] == '\0' || path[0] == '/') {
			continue;
		}
		char *candidate = path;
		if (bsearch(&candidate, excluded, excluded_count, sizeof(*excluded),
			compare_paths) != NULL) {
			continue;
		}

		snprintf(suffix, sizeof(suffix), ".wt-prewarm-clone.%ld.%llu",
			(long)getpid(), sequence++);
		source = join_path(argv[1], path, "");
		target = join_path(argv[2], path, "");
		temporary = join_path(argv[2], path, suffix);
		if (source == NULL || target == NULL || temporary == NULL) {
			free(source);
			free(target);
			free(temporary);
			free(path);
			return 3;
		}

		if (lstat(source, &source_before) != 0 ||
			lstat(target, &target_stat) != 0 ||
			!S_ISREG(source_before.st_mode) || !S_ISREG(target_stat.st_mode)) {
			goto next;
		}

		if (clonefile(source, temporary, CLONE_NOFOLLOW) != 0) {
			goto next;
		}

		/* clonefile is exact; this guards against a source edit racing it. */
		if (lstat(source, &source_after) != 0 ||
			!unchanged(&source_before, &source_after)) {
			unlink(temporary);
			goto next;
		}

		target_times[0] = target_stat.st_atimespec;
		target_times[1] = target_stat.st_mtimespec;
		if (chmod(temporary, target_stat.st_mode & 07777) != 0 ||
			utimensat(AT_FDCWD, temporary, target_times, 0) != 0 ||
			lstat(target, &target_after) != 0 ||
			!unchanged(&target_stat, &target_after) || rename(temporary, target) != 0) {
			unlink(temporary);
			goto next;
		}

		cloned++;

	next:
		free(source);
		free(target);
		free(temporary);
	}

	if (ferror(stdin)) {
		for (size_t index = 0; index < excluded_count; index++) {
			free(excluded[index]);
		}
		free(excluded);
		free(path);
		return 4;
	}

	for (size_t index = 0; index < excluded_count; index++) {
		free(excluded[index]);
	}
	free(excluded);
	free(path);
	printf("%llu\n", cloned);
	return 0;
}

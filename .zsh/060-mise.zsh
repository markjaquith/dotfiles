# Configure HK to use Mise
# See: https://hk.jdx.dev/mise_integration.html
export HK_MISE=1

# Load Mise unless SKIP_MISE is set.
if [[ -z "$SKIP_MISE" ]]; then
	eval "$(mise activate zsh)"
fi

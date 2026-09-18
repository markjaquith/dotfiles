const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/alpha/decisions"
const TYPESAFE_ENDPOINT = "https://api.typesafe.ai/v1/systemone"

interface NoulResponse {
	answers?: {
		evaluation?: {
			type?: string
			noul?: number
		}
	}
}

interface JevRequest {
	state: unknown
	question: string
}

function configuration() {
	if (process.env.OPENROUTER_API_KEY !== undefined) {
		return {
			endpoint: process.env.OPENROUTER_ENDPOINT ?? OPENROUTER_ENDPOINT,
			key: process.env.OPENROUTER_API_KEY,
			keyName: "OPENROUTER_API_KEY",
			model: "typesafe/jev-1.13",
		}
	}

	return {
		endpoint: process.env.TYPESAFE_ENDPOINT ?? TYPESAFE_ENDPOINT,
		key: process.env.TYPESAFE_API_KEY,
		keyName: "TYPESAFE_API_KEY",
		model: "jev-latest",
	}
}

function errorMessage(status: number) {
	if (status === 401 || status === 403) return "check the configured API key"
	if (status === 422) return "the question or message context was rejected"
	if (status === 429 || status === 529) return "the service is busy"
	return "the request was unsuccessful"
}

export async function evaluateNoul({ state, question }: JevRequest) {
	const config = configuration()
	if (!config.key?.trim()) {
		throw new Error(
			`Set OPENROUTER_API_KEY or TYPESAFE_API_KEY (${config.keyName} is not set).`,
		)
	}

	const body = {
		model: config.model,
		state,
		questions: {
			evaluation: {
				type: "noul",
				instructions: question,
			},
		},
	}

	for (let attempt = 0; attempt < 3; attempt++) {
		const response = await fetch(config.endpoint, {
			method: "POST",
			headers: {
				authorization: `Bearer ${config.key}`,
				"content-type": "application/json",
			},
			body: JSON.stringify(body),
			signal: AbortSignal.timeout(120_000),
		})

		if ((response.status === 429 || response.status === 529) && attempt < 2) {
			await Bun.sleep(2 ** attempt * 1_000)
			continue
		}
		if (!response.ok) {
			throw new Error(
				`Jev returned HTTP ${response.status}: ${errorMessage(response.status)}.`,
			)
		}

		const payload = (await response.json()) as NoulResponse
		const answer = payload.answers?.evaluation
		const noul = answer?.noul
		if (
			answer?.type !== "noul" ||
			typeof noul !== "number" ||
			!Number.isFinite(noul) ||
			noul < 0 ||
			noul > 1
		) {
			throw new Error("Jev returned an invalid Noul answer.")
		}
		return noul
	}

	throw new Error("Jev did not return an answer.")
}

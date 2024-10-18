import express from "express"
import * as pty from 'node-pty'

function sleep(n: number): Promise<void> {
	return new Promise((resolve) => {
		setTimeout(resolve, n)
	})
}

class ShellSession {
	private readonly proc

	private out = ''

	constructor(w: number, h: number, name = 'xterm-256color') {
		this.proc = pty.spawn('zsh', [], {
			name,
			cols: w,
			rows: h,
			cwd: process.env.HOME,
			env: process.env,
		})
		this.proc.onData((data) => {
			this.out += data
		})
	}

	public async update(input: string) {
		if (input != '') {
			this.proc.write(input)
		}
		await sleep(10)
		const data = this.out
		this.out = ''
		return data
	}
}

const Sessions = new Map<string, ShellSession>()

const app = express()
const port = 3000

app.use(express.json())

app.get('/', (req, res) => {
	res.send('Hello World!')
})

app.get('/session', (req, res) => {
	const id = crypto.randomUUID()
	const w = Number(req.query['w'] ?? 60)
	const h = Number(req.query['h'] ?? 40)
	const session = new ShellSession(w, h, req.query['name'] as string)
	Sessions.set(id, session)
	res.json({ session: id, w, h })
})

app.post('/session/:sessionid', async (req, res) => {
	const id = req.params.sessionid
	const session = Sessions.get(id)
	if (!session) {
		res.json({ error: 'Invalid session id' })
		return
	}
	const body: { body: string } = req.body
	const out = await session.update(body.body)
	res.send(out)
})

app.listen(port, () => {
	console.log(`Listening on port ${port}`)
})

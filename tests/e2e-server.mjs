import { createReadStream, existsSync, statSync } from 'node:fs'
import { extname, join, normalize, resolve } from 'node:path'
import { createServer } from 'node:http'

const root = resolve(process.cwd(), process.env.E2E_DIST_DIR ?? 'dist/client')
const host = '127.0.0.1'
const port = Number(process.env.E2E_PORT ?? 4173)

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
}

if (!existsSync(join(root, 'index.html'))) {
  throw new Error(`E2E build output not found: ${root}`)
}

const server = createServer((request, response) => {
  const requestPath = decodeURIComponent(new URL(request.url ?? '/', `http://${host}:${port}`).pathname)
  const safePath = normalize(requestPath).replace(/^([/\\])+/, '')
  const requestedFile = resolve(root, safePath)
  const filePath = requestedFile.startsWith(root) && existsSync(requestedFile) && statSync(requestedFile).isFile()
    ? requestedFile
    : join(root, 'index.html')

  response.statusCode = 200
  response.setHeader('Content-Type', contentTypes[extname(filePath)] ?? 'application/octet-stream')
  createReadStream(filePath).pipe(response)
})

server.listen(port, host, () => {
  console.log(`E2E static server listening on http://${host}:${port}`)
})

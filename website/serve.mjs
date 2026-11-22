import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), 'dist');
const port = Number(process.env.PORT || 4173);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.mp4': 'video/mp4', '.xml': 'application/xml', '.txt': 'text/plain' };
http.createServer(async (req, res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    let target = path.resolve(root, '.' + pathname);
    if (target !== root && !target.startsWith(root + path.sep)) throw new Error('path');
    let status = 200;
    try { if ((await stat(target)).isDirectory()) target = path.join(target, 'index.html'); }
    catch { target = path.join(root, '404.html'); status = 404; }
    const bytes = await readFile(target);
    const size = bytes.length;
    res.setHeader('Content-Type', types[path.extname(target)] || 'application/octet-stream');
    const match = req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
    if (match && status === 200) {
      const start = Number(match[1]), end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
      if (start >= size || start > end) { res.writeHead(416, { 'Content-Range': `bytes */${size}` }); res.end(); return; }
      res.writeHead(206, { 'Content-Range': `bytes ${start}-${end}/${size}`, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1 });
      res.end(req.method === 'HEAD' ? undefined : bytes.subarray(start, end + 1)); return;
    }
    res.writeHead(status, { 'Content-Length': size, 'Accept-Ranges': 'bytes' });
    res.end(req.method === 'HEAD' ? undefined : bytes);
  } catch { res.writeHead(404); res.end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`Local: http://127.0.0.1:${port}`));

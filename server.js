const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;
const WEB_DIR = path.join(__dirname, 'web_build');

const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.wasm': 'application/wasm',
    '.pck': 'application/octet-stream',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.css': 'text/css; charset=utf-8'
};

const server = http.createServer((req, res) => {
    // Parse URL
    let reqPath = decodeURI(req.url.split('?')[0]);
    if (reqPath === '/' || reqPath === '') {
        reqPath = '/index.html';
    }

    const filePath = path.join(WEB_DIR, reqPath);

    // Security check: ensure path is within WEB_DIR
    if (!filePath.startsWith(WEB_DIR)) {
        res.writeHead(403);
        res.end('Forbidden');
        return;
    }

    fs.stat(filePath, (err, stats) => {
        if (err || !stats.isFile()) {
            res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end('File Not Found');
            return;
        }

        const ext = path.extname(filePath).toLowerCase();
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        const fileSize = stats.size;

        // Security & isolation headers for Chrome / WebAssembly
        const headers = {
            'Content-Type': contentType,
            'Cross-Origin-Opener-Policy': 'same-origin',
            'Cross-Origin-Embedder-Policy': 'require-corp',
            'Access-Control-Allow-Origin': '*',
            'Accept-Ranges': 'bytes',
            'Cache-Control': 'no-cache'
        };

        const range = req.headers.range;
        if (range) {
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

            if (start >= fileSize || end >= fileSize) {
                res.writeHead(416, {
                    'Content-Range': `bytes */${fileSize}`,
                    ...headers
                });
                return res.end();
            }

            const chunksize = (end - start) + 1;
            const fileStream = fs.createReadStream(filePath, { start, end });
            res.writeHead(206, {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Content-Length': chunksize,
                ...headers
            });
            fileStream.pipe(res);
        } else {
            res.writeHead(200, {
                'Content-Length': fileSize,
                ...headers
            });
            fs.createReadStream(filePath).pipe(res);
        }
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`=================================================`);
    console.log(`🚀 WRAP · 星际远征 Web版 本地服务已启动!`);
    console.log(`🎮 本地游玩地址: http://localhost:${PORT}`);
    console.log(`🌐 局域网地址:   http://0.0.0.0:${PORT}`);
    console.log(`=================================================`);
});

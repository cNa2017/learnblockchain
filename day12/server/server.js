import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import { createServer } from 'http';
import path from 'path';
import { Server } from 'socket.io';
import { fileURLToPath } from 'url';

// 加载环境变量
dotenv.config();

// 导入路由
import contractsRoutes from './routes/contracts.js';
import pollingLogsRoutes from './routes/polling-logs.js';
import transactionsRoutes from './routes/transactions.js';
import usersRoutes from './routes/users.js';

// 导入轮询服务
import { startPollingService } from './services/pollingService.js';

// 获取当前文件的目录
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 创建Express应用
const app = express();
const PORT = process.env.PORT || 3001;

// 创建HTTP服务器和Socket.io服务
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// 中间件
app.use(cors());
app.use(express.json());

// API路由
app.use('/api/users', usersRoutes);
app.use('/api/contracts', contractsRoutes);
app.use('/api/transactions', transactionsRoutes);
app.use('/api/polling-logs', pollingLogsRoutes);

// 提供静态文件（生产环境）
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../dist')));
  
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../dist/index.html'));
  });
}

// 启动服务器
httpServer.listen(PORT, () => {
  console.log(`服务器运行在端口 ${PORT}`);
  
  // 将Socket.io实例传递给轮询服务
  startPollingService(io);
});

// 处理未捕获的异常
process.on('uncaughtException', (error) => {
  console.error('未捕获的异常:', error);
});

process.on('unhandledRejection', (error) => {
  console.error('未处理的Promise拒绝:', error);
}); 
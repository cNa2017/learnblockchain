import axios from 'axios';

const API_URL = 'http://localhost:3001/api';
const TOKEN_KEY = 'erc20_explorer_token';
const USER_KEY = 'erc20_explorer_user';

// 登录用户
export const loginUser = async (address: string) => {
  try {
    const response = await axios.post(`${API_URL}/users/login`, { address });
    
    if (response.data.success) {
      // 保存令牌和用户信息
      localStorage.setItem(TOKEN_KEY, response.data.token);
      localStorage.setItem(USER_KEY, JSON.stringify(response.data.user));
      
      return response.data.user;
    } else {
      throw new Error(response.data.message || '登录失败');
    }
  } catch (error) {
    console.error('登录错误:', error);
    throw error;
  }
};

// 登出用户
export const logoutUser = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
};

// 获取存储的用户
export const getStoredUser = () => {
  const userData = localStorage.getItem(USER_KEY);
  return userData ? JSON.parse(userData) : null;
};

// 获取令牌
export const getToken = () => {
  return localStorage.getItem(TOKEN_KEY);
};

// 创建带认证的HTTP请求头
export const getAuthHeader = () => {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
};
export interface User {
  id: number;
  username: string;
  email: string;
  full_name: string;
  role: string;
  is_active: boolean;
  is_superuser: boolean;
  branch_id?: number;
  created_at: string;
  updated_at?: string;
}

export interface UserCreate {
  username: string;
  email: string;
  full_name: string;
  password: string;
  role?: string;
  branch_id?: number;
}

export interface AuthResponse {
  access_token: string;
  token_type: string;
}


/**
 * Common types for MSW handlers
 */

/**
 * Standard API response wrapper
 */
export interface ApiResponse<T = unknown> {
  success: boolean;
  data: T;
  message?: string;
}

/**
 * API Error response
 */
export interface ApiError {
  success: false;
  message: string;
  errors?: Record<string, string[]>;
  code?: string;
  statusCode?: number;
}

/**
 * Paginated API response
 */
export interface PaginatedResponse<T = unknown> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasMore: boolean;
  };
}

/**
 * Type guard for API errors
 */
export function isApiError(error: unknown): error is ApiError {
  if (typeof error !== 'object' || error === null) return false;
  const candidate = error as Partial<ApiError>;
  return candidate.success === false && typeof candidate.message === 'string';
}

/**
 * Extract error message from various error formats
 */
export function getErrorMessage(error: unknown): string {
  if (isApiError(error)) {
    return error.message;
  }

  const axiosLike = error as { response?: { data?: { message?: unknown } }; message?: unknown };

  if (typeof axiosLike?.response?.data?.message === 'string') {
    return axiosLike.response.data.message;
  }

  if (typeof axiosLike?.message === 'string') {
    return axiosLike.message;
  }

  return 'An unexpected error occurred';
}

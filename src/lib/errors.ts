/**
 * Utility functions for error handling
 */

/**
 * Extracts a user-friendly error message from various error types
 *
 * @param error - Error object of unknown type
 * @returns A string representation of the error message
 *
 * @example
 * ```ts
 * try {
 *   await someAsyncOperation();
 * } catch (error) {
 *   toast.error(getErrorMessage(error));
 * }
 * ```
 */
export function getErrorMessage(error: unknown): string {
  // Handle Error instances
  if (error instanceof Error) {
    return error.message;
  }

  // Handle Axios errors with response data
  if (
    error &&
    typeof error === 'object' &&
    'response' in error &&
    error.response &&
    typeof error.response === 'object'
  ) {
    const response = error.response as {
      data?: { message?: string; error?: string };
      statusText?: string;
    };

    // Try to extract message from response data
    if (response.data) {
      if (response.data.message) {
        return response.data.message;
      }
      if (response.data.error) {
        return response.data.error;
      }
    }

    // Fall back to status text
    if (response.statusText) {
      return response.statusText;
    }
  }

  // Handle string errors
  if (typeof error === 'string') {
    return error;
  }

  // Handle objects with message property
  if (
    error &&
    typeof error === 'object' &&
    'message' in error &&
    typeof error.message === 'string'
  ) {
    return error.message;
  }

  // Default fallback
  return 'An unknown error occurred';
}

/**
 * Checks if an error is a network error
 *
 * @param error - Error object of unknown type
 * @returns True if the error appears to be a network error
 *
 * @example
 * ```ts
 * if (isNetworkError(error)) {
 *   toast.error('Please check your internet connection');
 * }
 * ```
 */
export function isNetworkError(error: unknown): boolean {
  if (error instanceof Error) {
    return (
      error.message.toLowerCase().includes('network') ||
      error.message.toLowerCase().includes('fetch') ||
      error.name === 'NetworkError'
    );
  }

  if (error && typeof error === 'object' && 'code' in error && typeof error.code === 'string') {
    return ['ENOTFOUND', 'ECONNREFUSED', 'ETIMEDOUT', 'ENETUNREACH'].includes(error.code);
  }

  return false;
}

/**
 * Checks if an error is an HTTP error with a specific status code
 *
 * @param error - Error object of unknown type
 * @param statusCode - HTTP status code to check for
 * @returns True if the error matches the status code
 *
 * @example
 * ```ts
 * if (isHttpError(error, 404)) {
 *   toast.error('Resource not found');
 * } else if (isHttpError(error, 401)) {
 *   // Redirect to login
 * }
 * ```
 */
export function isHttpError(error: unknown, statusCode: number): boolean {
  if (
    error &&
    typeof error === 'object' &&
    'response' in error &&
    error.response &&
    typeof error.response === 'object' &&
    'status' in error.response
  ) {
    return error.response.status === statusCode;
  }

  return false;
}

/**
 * Formats validation errors from API responses
 *
 * @param error - Error object that may contain validation errors
 * @returns An object mapping field names to error messages, or null if no validation errors
 *
 * @example
 * ```ts
 * const validationErrors = getValidationErrors(error);
 * if (validationErrors) {
 *   Object.entries(validationErrors).forEach(([field, message]) => {
 *     form.setError(field, { message });
 *   });
 * }
 * ```
 */
export function getValidationErrors(error: unknown): Record<string, string> | null {
  if (
    error &&
    typeof error === 'object' &&
    'response' in error &&
    error.response &&
    typeof error.response === 'object' &&
    'data' in error.response &&
    error.response.data &&
    typeof error.response.data === 'object' &&
    'errors' in error.response.data
  ) {
    const errors = error.response.data.errors;

    if (errors && typeof errors === 'object') {
      return errors as Record<string, string>;
    }
  }

  return null;
}

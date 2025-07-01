# Security Report

This report summarizes the security policies that have been applied to the application and the results of the policy tests.

## Policies

*   **deny-all:** This policy denies all traffic by default.
*   **allow-frontend-to-backend:** This policy allows traffic from the `frontend` service to the `backend` service.

## Test Results

*   **Test 1: Access the frontend:** This test was successful, as expected.
*   **Test 2: Access the backend directly:** This test was blocked, as expected.

# Python Executor
# This module handles the actual execution of user code with timeout and output capture.

import sys
from io import StringIO

class _TimeoutError(Exception):
    """Custom timeout exception for execution time limit."""
    pass


def execute_code(compiled_code, user_globals, timeout_seconds):
    """
    Execute compiled user code with timeout and output capture.
    
    Args:
        compiled_code: Pre-compiled code object from compile()
        user_globals: The globals dict for execution
        timeout_seconds: Maximum execution time in seconds
    
    Returns:
        Tuple of (stdout_output, stderr_output, error_message)
        error_message is None if execution succeeded
    """
    import time as _time
    
    _start_time = _time.time()
    
    def _timeout_trace(frame, event, arg):
        if _time.time() - _start_time > timeout_seconds:
            raise _TimeoutError(f"Execution exceeded {timeout_seconds} second time limit")
        return _timeout_trace
    
    _stdout_capture = StringIO()
    _stderr_capture = StringIO()
    _old_stdout = sys.stdout
    _old_stderr = sys.stderr
    sys.stdout = _stdout_capture
    sys.stderr = _stderr_capture
    
    _exec_error = None
    _captured_stdout = ""
    _captured_stderr = ""
    
    try:
        sys.settrace(_timeout_trace)
        exec(compiled_code, user_globals)
    except _TimeoutError as e:
        _exec_error = str(e)
    except Exception as e:
        import traceback
        _exec_error = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
    finally:
        sys.settrace(None)
        sys.stdout = _old_stdout
        sys.stderr = _old_stderr
        _captured_stdout = _stdout_capture.getvalue()
        _captured_stderr = _stderr_capture.getvalue()
    
    return (_captured_stdout, _captured_stderr, _exec_error)

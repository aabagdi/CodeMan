# Python Executor
# This module handles the actual execution of user code with timeout and output capture.

import sys
from io import StringIO

class _TimeoutError(BaseException):
    """Custom timeout exception for execution time limit.
    
    Inherits from BaseException (not Exception) so that user code with
    'except Exception:' or 'except:' clauses cannot suppress the timeout.
    """
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
    _timed_out = False
    
    def _timeout_trace(frame, event, arg):
        nonlocal _timed_out
        if _timed_out or _time.time() - _start_time > timeout_seconds:
            # Set flag so that even if user code catches the exception,
            # the very next trace event will re-raise immediately.
            _timed_out = True
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
        import linecache
        
        # Build a compact error message without caret alignment
        error_parts = []
        exc_type = type(e).__name__
        exc_msg = str(e)
        
        # Walk the traceback to find user code frames
        tb = e.__traceback__
        user_frames = []
        while tb is not None:
            frame = tb.tb_frame
            filename = frame.f_code.co_filename
            # Only include frames from user code
            if filename == "<user_code>":
                lineno = tb.tb_lineno
                line = linecache.getline(filename, lineno).strip()
                user_frames.append((lineno, line))
            tb = tb.tb_next
        
        # Format the error with position info
        if user_frames:
            # Show error location(s)
            for lineno, line in user_frames:
                error_parts.append(f"Line {lineno}: {line}")
            error_parts.append("")
        
        error_parts.append(f"{exc_type}: {exc_msg}")
        _exec_error = "\n".join(error_parts)
    finally:
        sys.settrace(None)
        sys.stdout = _old_stdout
        sys.stderr = _old_stderr
        _captured_stdout = _stdout_capture.getvalue()
        _captured_stderr = _stderr_capture.getvalue()
    
    return (_captured_stdout, _captured_stderr, _exec_error)

namespace CloudSoft.Models;

public class OperationResult
{
    public bool IsSuccess { get; private set; }
    public string Message { get; private set; } = string.Empty;

    public static OperationResult Success(string message = "") => new() { IsSuccess = true, Message = message };
    public static OperationResult Failure(string message = "") => new() { IsSuccess = false, Message = message };
}

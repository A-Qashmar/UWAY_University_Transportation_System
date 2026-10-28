using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace UWAY.Api.Controllers;

internal static class DatabaseErrorResponses
{
    public static bool IsUniqueViolation(DbUpdateException exception) =>
        exception.GetBaseException() is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation };

    public static bool IsConstraintViolation(DbUpdateException exception) =>
        exception.GetBaseException() is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation or
                PostgresErrorCodes.ForeignKeyViolation or
                PostgresErrorCodes.CheckViolation
        };

    public static ConflictObjectResult ConstraintConflict(ControllerBase controller, DbUpdateException exception)
    {
        var postgresException = (PostgresException)exception.GetBaseException();
        var message = postgresException.SqlState == PostgresErrorCodes.UniqueViolation
            ? "A record with that unique value already exists."
            : "This record is referenced by other project data or violates a data rule.";

        return controller.Conflict(new ProblemDetails
        {
            Status = StatusCodes.Status409Conflict,
            Title = "The requested change conflicts with existing data.",
            Detail = message
        });
    }
}

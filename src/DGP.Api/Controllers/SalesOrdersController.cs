using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class SalesOrdersController : ControllerBase
{
    private readonly ISalesOrderService _salesOrderService;

    public SalesOrdersController(ISalesOrderService salesOrderService)
    {
        _salesOrderService = salesOrderService;
    }

    [HttpPost("{salesOrderId:long}/confirm")]
    public async Task<IActionResult> Confirm(long salesOrderId, [FromQuery] string confirmedBy = "system")
    {
        var result = await _salesOrderService.ConfirmAsync(salesOrderId, confirmedBy);
        return Ok(new { success = result, message = result ? "Sales order confirmed." : "Unable to confirm sales order.", data = result });
    }

    [HttpPost("{salesOrderId:long}/revision")]
    public async Task<IActionResult> CreateRevision(long salesOrderId, [FromQuery] string reason = "revision", [FromQuery] string createdBy = "system")
    {
        var revisionId = await _salesOrderService.CreateRevisionAsync(salesOrderId, reason, createdBy);
        return Ok(new { success = true, message = "Revision created.", data = revisionId });
    }
}

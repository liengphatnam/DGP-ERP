using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class InventoryController : ControllerBase
{
    private readonly IInventoryTransactionService _inventoryTransactionService;
    private readonly IInventoryBalanceService _inventoryBalanceService;

    public InventoryController(IInventoryTransactionService inventoryTransactionService, IInventoryBalanceService inventoryBalanceService)
    {
        _inventoryTransactionService = inventoryTransactionService;
        _inventoryBalanceService = inventoryBalanceService;
    }

    [HttpGet("balance")]
    public async Task<IActionResult> GetBalance([FromQuery] string? itemCode = null, [FromQuery] string? warehouseCode = null)
    {
        var result = await _inventoryBalanceService.GetBalancesAsync(itemCode, warehouseCode);
        return Ok(new { success = true, message = "OK", data = result });
    }

    [HttpPost("issue-to-print")]
    public async Task<IActionResult> IssueToPrint([FromQuery] long itemId, [FromQuery] long warehouseId, [FromQuery] decimal qty, [FromQuery] string createdBy = "system")
    {
        var result = await _inventoryTransactionService.RecordTransactionAsync(itemId, warehouseId, "ISSUE_TO_PRINT", -qty, "PCS", "ISSUE_TO_PRINT", null, null, "Issue to print", createdBy);
        return Ok(new { success = true, message = "Issue recorded.", data = result });
    }
}

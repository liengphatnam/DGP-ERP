using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class WipController : ControllerBase
{
    private readonly IWipService _wipService;

    public WipController(IWipService wipService)
    {
        _wipService = wipService;
    }

    [HttpPost("start-stage")]
    public async Task<IActionResult> StartStage([FromQuery] long productionOrderId, [FromQuery] long stageId, [FromQuery] long itemId, [FromQuery] decimal qty, [FromQuery] string createdBy = "system")
    {
        var result = await _wipService.StartStageAsync(productionOrderId, stageId, itemId, qty, null, createdBy);
        return Ok(new { success = true, message = "Stage started.", data = result });
    }

    [HttpPost("finish-stage")]
    public async Task<IActionResult> FinishStage([FromQuery] long productionOrderId, [FromQuery] long stageId, [FromQuery] long itemId, [FromQuery] decimal qty, [FromQuery] decimal scrapQty = 0, [FromQuery] string createdBy = "system")
    {
        var result = await _wipService.FinishStageAsync(productionOrderId, stageId, itemId, qty, scrapQty, null, createdBy);
        return Ok(new { success = true, message = "Stage finished.", data = result });
    }
}

using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class WaveController : ControllerBase
{
    private readonly IWavePlanService _wavePlanService;
    private readonly ICorrugatorLayoutOptimizerService _layoutOptimizer;

    public WaveController(IWavePlanService wavePlanService, ICorrugatorLayoutOptimizerService layoutOptimizer)
    {
        _wavePlanService = wavePlanService;
        _layoutOptimizer = layoutOptimizer;
    }

    [HttpPost("layout/suggest")]
    public async Task<IActionResult> SuggestLayout([FromQuery] string machineCode, [FromQuery] decimal singleSheetWidthMm, [FromQuery] decimal singleSheetLengthMm, [FromQuery] decimal requiredSheetQty)
    {
        var result = await _layoutOptimizer.SuggestLayoutAsync(machineCode, singleSheetWidthMm, singleSheetLengthMm, requiredSheetQty);
        return Ok(new { success = true, message = "OK", data = result });
    }

    [HttpPost("plans")]
    public async Task<IActionResult> CreatePlan([FromQuery] string machineCode, [FromQuery] string fluteCode, [FromQuery] decimal runWidthMm, [FromQuery] string waveRequirementIds, [FromQuery] string createdBy = "system")
    {
        var ids = waveRequirementIds.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(long.Parse);

        var result = await _wavePlanService.CreateWavePlanAsync(machineCode, fluteCode, runWidthMm, ids, createdBy);
        return Ok(new { success = true, message = "Wave plan created.", data = result });
    }
}

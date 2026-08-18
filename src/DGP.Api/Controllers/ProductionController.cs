using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class ProductionController : ControllerBase
{
    private readonly IProductionOrderService _productionOrderService;
    private readonly IWaveRequirementService _waveRequirementService;

    public ProductionController(IProductionOrderService productionOrderService, IWaveRequirementService waveRequirementService)
    {
        _productionOrderService = productionOrderService;
        _waveRequirementService = waveRequirementService;
    }

    [HttpPost("create-from-line/{lineId:long}")]
    public async Task<IActionResult> CreateFromLine(long lineId, [FromQuery] string createdBy = "system")
    {
        var poId = await _productionOrderService.CreateFromSalesOrderLineAsync(lineId, createdBy);
        return Ok(new { success = true, message = "Production order created.", data = poId });
    }

    [HttpPost("generate-wave-requirement/{productionOrderId:long}")]
    public async Task<IActionResult> GenerateWaveRequirement(long productionOrderId, [FromQuery] string createdBy = "system")
    {
        var waveReqId = await _waveRequirementService.GenerateFromCatalogAsync(productionOrderId, createdBy);
        return Ok(new { success = true, message = "Wave requirement generated.", data = waveReqId });
    }
}

using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class CatalogController : ControllerBase
{
    private readonly ICatalogLookupService _catalogLookupService;

    public CatalogController(ICatalogLookupService catalogLookupService)
    {
        _catalogLookupService = catalogLookupService;
    }

    [HttpGet("lookup/{itemCode}")]
    public async Task<IActionResult> Lookup(string itemCode)
    {
        var result = await _catalogLookupService.GetCatalogAsync(itemCode);
        return Ok(new { success = true, message = "OK", data = result });
    }
}

using DGP.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace DGP.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class ItemsController : ControllerBase
{
    private readonly ICatalogLookupService _catalogLookupService;

    public ItemsController(ICatalogLookupService catalogLookupService)
    {
        _catalogLookupService = catalogLookupService;
    }

    [HttpGet("catalog/{itemCode}")]
    public async Task<IActionResult> GetCatalog(string itemCode)
    {
        var result = await _catalogLookupService.GetCatalogAsync(itemCode);
        return Ok(new { success = true, message = "OK", data = result });
    }
}

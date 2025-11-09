using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;

namespace Nimbus.Autopilot.Api.Controllers;

public class HomeController : Controller
{
    [AllowAnonymous]
    public IActionResult Index()
    {
        return View();
    }

    [Authorize(Roles = "Administrator")]
    public IActionResult Dashboard()
    {
        return View();
    }
}

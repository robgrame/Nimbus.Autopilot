using Microsoft.AspNetCore.Mvc;

namespace Nimbus.Autopilot.Api.Controllers;

public class HomeController : Controller
{
    public IActionResult Index()
    {
        return View();
    }

    public IActionResult Dashboard()
    {
        return View();
    }
}

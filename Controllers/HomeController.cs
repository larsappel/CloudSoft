using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using CloudSoft.Models;
using CloudSoft.Services;

namespace CloudSoft.Controllers;

public class HomeController : Controller
{
    private readonly IImageService _imageService;

    public HomeController(IImageService imageService)
    {
        _imageService = imageService;
    }

    public IActionResult Index()
    {
        return View();
    }

    public IActionResult About()
    {
        ViewData["HeroImageUrl"] = _imageService.GetImageUrl("hero.jpg");
        return View();
    }

    public IActionResult Privacy()
    {
        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}

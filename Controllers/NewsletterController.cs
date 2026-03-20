using CloudSoft.Models;
using CloudSoft.Services;
using Microsoft.AspNetCore.Mvc;

namespace CloudSoft.Controllers;

public class NewsletterController : Controller
{
    private readonly INewsletterService _newsletterService;

    public NewsletterController(INewsletterService newsletterService)
    {
        _newsletterService = newsletterService;
    }

    [HttpGet]
    public IActionResult Subscribe()
    {
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Subscribe(Subscriber subscriber)
    {
        if (!ModelState.IsValid)
            return View(subscriber);

        var result = await _newsletterService.SubscribeAsync(subscriber);
        TempData["Message"] = result.Message;
        TempData["IsSuccess"] = result.IsSuccess.ToString();

        return RedirectToAction(nameof(Subscribe));
    }

    [HttpGet]
    public async Task<IActionResult> Subscribers()
    {
        var subscribers = await _newsletterService.GetSubscribersAsync();
        return View(subscribers);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Unsubscribe(string email)
    {
        var result = await _newsletterService.UnsubscribeAsync(email);
        TempData["Message"] = result.Message;
        TempData["IsSuccess"] = result.IsSuccess.ToString();

        return RedirectToAction(nameof(Subscribers));
    }
}

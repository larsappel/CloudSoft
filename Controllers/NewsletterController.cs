using CloudSoft.Models;
using Microsoft.AspNetCore.Mvc;

namespace CloudSoft.Controllers;

public class NewsletterController : Controller
{

    [HttpGet]
    public IActionResult Subscribe()
    {
        return View();
    }

    [HttpPost]
    public IActionResult Subscribe(Subscriber subscriber)
    {
        // Add subscription logic here
        // ...

        // Write to the console
        Console.WriteLine($"New subscription - Name: {subscriber.Name} Email: {subscriber.Email}");

        // Send a message to the user
        ViewBag.Message = $"Thank you for subscribing, {subscriber.Name}!";

        // Return the view
        return View();
    }
}

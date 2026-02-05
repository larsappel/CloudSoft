using Microsoft.AspNetCore.Mvc;

namespace CloudSoft.Controllers;

public class NewsletterController : Controller
{

    // GET: /Newsletter/Subscribe
    public IActionResult Subscribe()
    {
        return View();
    }

    // POST: /Newsletter/Subscribe
    [HttpPost]
    public IActionResult Subscribe(string name, string email)
    {
        // Add subscription logic here
        // ...

        // Write to the console
        Console.WriteLine($"New subscription - Name: {name} Email: {email}");

        // Send a message to the user
        return Content($"Thank you {name} for subscribing to our newsletter!");
    }
}

using System.ComponentModel.DataAnnotations;

namespace CloudSoft.Models;

public class Subscriber
{
    [Required]
    [StringLength(20, ErrorMessage = "Name cannot exceed 20 characters")]
    public string? Name { get; set; }

    [Required]
    [EmailAddress]
    public string? Email { get; set; }
}

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BellwoodAuthServer.Controllers
{
    public class AuthorizationController : Controller
    {
        [HttpGet("/connect/authorize")]
        [Authorize]
        public IActionResult Authorize()
        {
            // TODO: show consent screen or immediately accept
            return View();
        }
    }
}

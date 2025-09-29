using System.Collections.Concurrent;

namespace BellwoodAuthServer.Services;

public class RefreshTokenStore
{
    private readonly ConcurrentDictionary<string, string> _rtToUser = new();

    public string Issue(string username)
    {
        var token = Guid.NewGuid().ToString("N");
        _rtToUser[token] = username;
        return token;
    }

    public bool TryRedeem(string refreshToken, out string username)
    {
        if (_rtToUser.TryRemove(refreshToken, out username))
            return true;
        username = "";
        return false;
    }
}

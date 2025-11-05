# IT Request Template for Netskope Bypass

Use this template when requesting bypass rules from your IT/Security team.

---

## Email Template

**Subject:** Netskope Bypass Request - Docker + External APIs

**To:** IT Security Team / Netskope Administrators

---

Hi Security Team,

We're experiencing SSL certificate verification errors when running containerized applications (Docker) that need to access external APIs due to Netskope SSL inspection.

### Issue Summary

**Problem:** Docker containers cannot verify Netskope's SSL certificate, causing application failures and blocking development workflows.

**Impact:**
- Development team blocked from running containerized applications
- Unable to pull packages from external registries (NPM, PyPI, Maven)
- API integrations failing (Google Cloud, AWS, Azure, etc.)
- CI/CD pipelines failing

### Request

Please add bypass rules for the following Docker processes:

**Process Names:**
- `com.docker.backend`
- `com.docker.vpnkit`
- `docker`
- `containerd`

**Domains to Bypass:**

**Critical (Package Managers):**
- `registry.npmjs.org` (NPM)
- `pypi.org` and `files.pythonhosted.org` (Python)
- `repo.maven.apache.org` (Maven)
- `registry.yarnpkg.com` (Yarn)

**Development Tools:**
- `github.com`, `*.github.com`, `raw.githubusercontent.com` (Git operations)
- `ghcr.io` (GitHub Container Registry)

**Cloud Provider APIs (choose relevant ones):**
- `*.googleapis.com` (Google Cloud APIs)
- `*.amazonaws.com` (AWS APIs)
- `*.azure.com` (Azure APIs)

**Alternative (if wildcard not possible):**
Specific domains we need:
- [List your specific API endpoints here]

### Business Justification

- **Team affected:** [Your team name]
- **Applications impacted:** [List applications]
- **Development delay:** [Estimated delay without bypass]
- **Security note:** These connections use certificate pinning and cannot work with SSL inspection

### Supporting Evidence

- Netskope logs show [XXX] intercepted connections over [time period]
- Error logs available upon request
- Affects [XX] developers on team

### Timeline

Request approval by: [Date]
Required for: [Reason/deadline]

### Alternative Solutions Considered

1. **Trusting Netskope certificate in containers** - Requires rebuilding all images, not feasible for third-party images
2. **Using different registry mirrors** - Not available for all services
3. **Manual workarounds** - Not scalable, impacts productivity

### Questions?

Happy to provide additional details or logs to support this request.

Thank you,
[Your Name]
[Your Team]

---

## Tips for Success

### 1. Be Specific
- List exact domains needed, not just wildcards
- Provide process names from Netskope logs
- Include actual error messages

### 2. Show Business Impact
- Number of developers affected
- Projects blocked
- Timeline impact

### 3. Provide Evidence
- Attach Netskope diagnostic logs
- Include error screenshots
- Show failed pipeline logs

### 4. Offer Compromise
- Start with minimal domain list
- Offer to review after 30 days
- Suggest pilot with small team first

### 5. Follow Security Process
- Use official IT ticketing system
- CC relevant managers
- Follow up weekly

---

## Common Objections & Responses

### "Can't you just trust our certificate?"

**Response:**
> We can for our own applications, but not for:
> - Third-party Docker images (can't rebuild)
> - Tools that use certificate pinning (security requirement)
> - Package managers that verify signatures
>
> Bypass is the recommended approach per Netskope documentation.

### "Bypass reduces security visibility"

**Response:**
> We're requesting bypass only for:
> - Trusted external services (Google, NPM, GitHub)
> - Services that already use certificate pinning
> - Non-sensitive development traffic
>
> Sensitive APIs (internal services, financial) will still be inspected.

### "This affects too many domains"

**Response:**
> We can start with a pilot:
> - Just Docker processes (not system-wide)
> - Just package managers initially
> - Expand after proving security model
> - Review quarterly and remove unused domains

### "Use a different solution"

**Response:**
> We evaluated:
> 1. Certificate trust - Not feasible for 3rd party images
> 2. Registry mirrors - Not available for all sources
> 3. VPN-based solutions - Adds latency, complexity
>
> Bypass is standard practice at [Similar Company Names] and recommended by Netskope for certificate-pinned applications.

---

## Escalation Path

If initial request is denied:

1. **Week 1:** Submit detailed request with evidence
2. **Week 2:** Follow up with manager support
3. **Week 3:** Escalate to department head
4. **Week 4:** Request meeting with security team
5. **Week 5:** Propose pilot program (1-2 developers, 2 weeks)

---

## Success Metrics

Track and report after bypass is granted:

- ✅ Reduction in SSL errors (from XX% to 0%)
- ✅ Faster build times (XX minutes → YY minutes)
- ✅ Unblocked developers (XX people)
- ✅ No security incidents related to bypass
- ✅ Maintained compliance with policies

Share these metrics with security team after 30/60/90 days.

---

## Related Resources

- **Netskope Documentation:** [Certificate Pinning Best Practices](https://docs.netskope.com/)
- **Docker Security:** [Certificate Management](https://docs.docker.com/engine/security/certificates/)
- **Alternative Solution:** [GitHub Repo - docker-netskope-ssl-fix](../)

---

**Good luck with your request!** 🍀

*Feel free to adapt this template to your organization's processes and requirements.*

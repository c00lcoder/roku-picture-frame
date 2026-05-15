sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    url = m.top.url
    if url = invalid or url = ""
        m.top.error = "No manifestUrl set in config/config.json"
        return
    end if

    body = invalid
    if Left(url, 4) = "http"
        xfer = CreateObject("roUrlTransfer")
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
        xfer.SetUrl(url)
        xfer.AddHeader("Accept", "application/json")
        xfer.RetainBodyOnError(true)
        body = xfer.GetToString()
    else
        body = ReadAsciiFile(url)
    end if

    if body = invalid or body = ""
        m.top.error = "Could not load manifest from " + url
        return
    end if

    parsed = ParseJson(body)
    if parsed = invalid
        m.top.error = "Manifest JSON is malformed"
        return
    end if

    images = parsed.images
    if images = invalid or images.Count() = 0
        m.top.error = "Manifest has no images"
        return
    end if

    m.top.result = parsed
end sub

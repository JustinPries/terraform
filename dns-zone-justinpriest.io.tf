resource "aws_route53_zone" "justinpriest-io" {
  name    = "justinpriest.io"
  comment = ""
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.justinpriest-io.id
  name    = "justinpriest.io"
  type    = "A"

  alias {
    name                   = "d13jeq0auko1i4.cloudfront.net"
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
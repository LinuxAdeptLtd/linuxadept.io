provider "aws" {
  region = "eu-west-2"
  alias  = "eu-west-2"
}

provider "aws" {
  region = "us-east-1"
  alias = "us-east-1"
}

data "aws_route53_zone" "route53_domain_linuxadept_io" {
  provider  = "aws.eu-west-2"
  name      = "linuxadept.io."
}

resource "aws_s3_bucket" "website_bucket" {
  provider  = "aws.eu-west-2"
  bucket    = "${var.linuxadept_io_primary_domain_name}"
  policy    = <<EOF
{
  "Id": "bucket_policy_site",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "bucket_policy_site_main",
      "Action": [
        "s3:GetObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${var.linuxadept_io_primary_domain_name}/*",
      "Principal": "*"
    }
  ]
}
EOF
  website {
    index_document = "index.html"
    error_document = "404.html"
  }
  tags {
  }
  force_destroy = true
}

resource "aws_acm_certificate" "acm_cert" {
  provider                  = "aws.us-east-1"
  domain_name               = "${var.linuxadept_io_primary_domain_name}"
  subject_alternative_names = "${var.linuxadept_io_alias_domains}"
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validate_linuxadept_io" {
  provider  = "aws.eu-west-2"
  name      = "${lookup(aws_acm_certificate.acm_cert.domain_validation_options[count.index], "resource_record_name")}"
  type      = "${lookup(aws_acm_certificate.acm_cert.domain_validation_options[count.index], "resource_record_type")}"
  zone_id   = "${data.aws_route53_zone.route53_domain_linuxadept_io.zone_id}"
  records   = [ "${lookup(aws_acm_certificate.acm_cert.domain_validation_options[count.index], "resource_record_value")}" ]
  ttl       = 60
  count     = "${length(var.linuxadept_io_alias_domains) + 1 }"
}

resource "aws_acm_certificate_validation" "acm_cert" {
  provider                = "aws.us-east-1"
  certificate_arn         = "${aws_acm_certificate.acm_cert.arn}"
}

resource "aws_cloudfront_distribution" "cdn" {
  provider  = "aws.eu-west-2"
  aliases = ["${var.linuxadept_io_alias_domains}"]
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.linuxadept_io_primary_domain_name}"
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  http_version = "http2"
  origin {
    origin_id   = "${var.linuxadept_io_primary_domain_name}"
    domain_name = "${var.linuxadept_io_primary_domain_name}.s3.amazonaws.com"
  }
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate_validation.acm_cert.certificate_arn}"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }
}

resource "aws_route53_record" "route53_env_linuxadept_io" {
  provider  = "aws.eu-west-2"
  zone_id   = "${data.aws_route53_zone.route53_domain_linuxadept_io.zone_id}"
  name      = "${var.linuxadept_io_primary_domain_name}"
  type      = "A"
  alias {
    name                    = "${aws_cloudfront_distribution.cdn.domain_name}"
    zone_id                 = "${aws_cloudfront_distribution.cdn.hosted_zone_id}"
    evaluate_target_health  = false
  }
}


resource "aws_route53_record" "route53_env_alias_linuxadept_io" {
  provider  = "aws.eu-west-2"
  zone_id   = "${data.aws_route53_zone.route53_domain_linuxadept_io.zone_id}"
  name      = "${var.linuxadept_io_alias_domains[count.index]}"
  type      = "A"
  alias {
    name                    = "${aws_cloudfront_distribution.cdn.domain_name}"
    zone_id                 = "${aws_cloudfront_distribution.cdn.hosted_zone_id}"
    evaluate_target_health  = false
  }
  count     = "${length(var.linuxadept_io_alias_domains)}"
}

require "./spec_helper"

require "uri"

describe AwsSignerV4::Signature do
  let(:access_key_id) { "ACCESSKEYID" }
  let(:secret_access_key) { "SECRETACCESSKEY" }
  let(:region) { "ap-northeast-1" }
  let(:service) { "service" }
  let(:uri) { URI.parse("https://example.org/foo/bar?baz=blah") }
  let(:verb) { "PUT" }
  let(:headers) do
    { "x-foo" => "bar" } of String => String?
  end
  let(:body) { "body" }
  let(:options) do
    {} of Symbol => String?
  end

  let(:signature) do
    AwsSignerV4::Signature.new(
      access_key_id,
      secret_access_key,
      region,
      service,
      uri,
      verb,
      headers,
      body,
      options
    )
  end

  describe "headers" do
    describe "without x-amz-date" do
      it "should be assigned" do
        assert signature.headers["x-amz-date"].is_a?(String)
      end
    end

    describe "with x-amz-date" do
      let(:headers) do
        { "x-amz-date" => "20151215T164227Z" } of String => String?
      end

      it "should not be assigned" do
        assert signature.headers["x-amz-date"].is_a?(String)
        assert Time.new(2015, 12, 15, 16, 42, 27, 0, Time::Kind::Utc) == signature.date
      end
    end

    describe "without host" do
      it "should be assigned" do
        assert "example.org" == signature.headers["Host"]
      end
    end

    describe "with host" do
      let(:headers) do
        { "host" => "example.com" } of String => String?
      end

      it "should not be assigned" do
        assert "example.com" == signature.headers["Host"]
      end
    end

    describe "with security token" do
      let(:security_token) { "session_token" }

      let(:options) do
        { security_token: security_token }
      end

      it "should be assigned as x-amz-security-token" do
        assert security_token == signature.headers["x-amz-security-token"]
      end
    end
  end

  describe "canonical_headers" do
    let(:headers) do
      {
        "x-test-b" => "2",
        "X-Test-A" => "1",
        "x-test-c" => "3",
        "Authorization" => "skip",
      } of String => String?
    end

    it "should end with return" do
      assert '\n' == signature.canonical_headers.to_s[-1]
    end

    it "should contain headers" do
      assert signature.canonical_headers.to_s.lines.includes?("x-test-b:2\n")
      assert signature.canonical_headers.to_s.lines.includes?("x-test-a:1\n") # downcase
      assert signature.canonical_headers.to_s.lines.includes?("x-test-c:3\n")
      assert !signature.canonical_headers.to_s.lines.includes?("Authorization:skip\n")
    end

    it "should sort headers" do
      assert %w(host x-amz-date x-test-a x-test-b x-test-c) ==
              signature.canonical_headers.to_s.lines.map { |line| line.split(/:/,2).first }
    end
  end

  describe "canonical_request" do
    before do
      headers["x-amz-date"] = "20140222T070605Z"
    end

    it "should return string to sign" do
      expected = <<-EXPECTED
PUT
/foo/bar
baz=blah
host:example.org
x-amz-date:20140222T070605Z
x-foo:bar

host;x-amz-date;x-foo
230d8358dc8e8890b4c58deeb62912ee2f20357ae92a5cc861b98e68fe31acb5
EXPECTED
      assert_equal expected.chomp, signature.canonical_request
    end
  end

  describe "hashed_payload" do
    let(:body) { "body" }

    it "should return hashed payload" do
      assert "230d8358dc8e8890b4c58deeb62912ee2f20357ae92a5cc861b98e68fe31acb5" == signature.hashed_payload
    end
  end

  describe "scope" do
    before do
      headers["x-amz-date"] = "20140222T070605Z"
    end

    it "should return scope" do
      assert "20140222/ap-northeast-1/service/aws4_request" == signature.scope
    end
  end
end

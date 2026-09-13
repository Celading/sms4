package consumer
import CjKu::sms4.*
main(): Int64 {
    let signer = RpcSigner()
    let query = signer.canonicalQuery([("Action", "SendSms"), ("Version", "2017-05-25")])
    println(signer.stringToSign(query))
    let q = RetryQueue(MockTransport())
    println(q.submit(SmsRequest("test-destination", "test-template")).ok)
    return 0
}

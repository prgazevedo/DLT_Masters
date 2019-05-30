



# Ethereum code

## Using Metamask

Open the javascript console in a browser with MetaMask running and type the following to get the current **nonce** of the EOA transactions.


```
web3.eth.getTransactionCount("0x9e713963a92c02317a681b9bb3065a8249de124f",function(error, result){
   if(!error)
       console.log(JSON.stringify(result));
   else
       console.error(error);
})
```
**note:** that this is a async call so we have to provide a callback function in the second argument.

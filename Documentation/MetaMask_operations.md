



# Ethereum code

## Using Metamask


Open the javascript console in a browser with MetaMask running and type the following

### Nonce value
In order to get the current **nonce** of the EOA transactions.


```
web3.eth.getTransactionCount("0x9e713963a92c02317a681b9bb3065a8249de124f",function(error, result){
   if(!error)
       console.log(JSON.stringify(result));
   else
       console.error(error);
})
```
**note:** that this is a async call so we have to provide a callback function in the second argument.

### Gas price
To get the gas price calculates the median price across several blocks
```
web3.eth.getGasPrice(console.log)
```
Result will be something like
```
null r {s: 1, e: 9, c: Array(1)}
c: [6000000000]
e: 9
s: 1
```

## Ordify
 
- `solidity` 0.8.23 used
- `foundry` for unit tests
- `echidna` - for advanced fuzz testing, with 40M runs. `2.2.2` version
- `forge script` - used for generating seed transactions that will be used in echidna for fuzz testing in assertion mode
- `foundry2echidna` - tool used to convert forge like transactions output to to echidna/etheno based trasnactions json file which will be used in echidna testing

# Contracts

All contracts are available in `src` folder

## OrdifyTOken
OrdifyTOken is ERC20 token wih maxSUpply of 100 M. THis token will laso extend LayerZero V2 OFT, whicih is base to use LayerZero as cross chain bridge in the future for ORFY token. 
OFT is an ERC-20 token that extends the functionality of the OFTCore contract.

## Staking

Staking - stake tokens and earn rewards based on defined staking defintions.
Owner can define up to 30 staking definitions, even this number is big, real use cases will have up to 10. 
Users can stake their tokens by choosing one of staking definitions which have defined lockDuration, prematured withdraw fee and rewarde yearly rate.


## Vesting
Once IDO participation is done and IDO token project will list their tokens Vesting contract will be created based on amount invested in IDO launchpad raise. 
On creation vesting  schedule is provided in phases by witch user will be able to claim their tokens. 
It supports cases when part(percentage) of the token was already given to users and rest will be claimed here, also supports many phases and cliff at the start. 
It supports vesting by block, which means user can vest every block some tokens, or by fixed amount of seconds and by whole phase, after phase is done user will claim some batch of tokens defined by percentage.

## Launchpad
Launchpad for raising funds. 
Only whitelisted users will be able to participated and whitelist is done by calculating user staking tiers by predifined Ordify rules. 
User can participate in round1 and round2. `Round1` is guaranteed round and once that round expires there is `round2` which is `FCFS` (First Come First serve) round which lasts 1 hour and users can buy  more tokens, 
Some IDO projects can be marked as registered interest onlu, which means before IDO user will have to register interest on Ordify IDO project page, and only those users will be
able to participate in guaranteed round, others will have round1 allocation set to 0, and will ahve only FCFS allocation.
User whitelisting is done offchain using ECDSA signature of combination(IDO contract address, user, round1Allocation, round2Allocation) and these data is required to participate so signature can be verified.

## AddressManagement

Contract used for users to store some non EVM addresses for distribution of tokens deployed on those chains if needed.


# Run echidna tests

`config.yaml` for each echidna test is can be updated with Echidna configuration: https://github.com/crytic/echidna/wiki/Config
Test mode used for tests were:
- "assertion": Detect assertion failures
- "optimization": Find the maximum value for a function.
- "overflow": Detect integer overflows (only available in Solidity 0.8.0 or greater).
- "exploration": Run contract code without executing any tests.



- `Staking`     -> `echidna --contract StakingEchidna       test/echidna/assertion/staking/StakingEchidna.sol       --config test/echidna/assertion/staking/config.yaml`
- `Vesting`     -> `echidna --contract VestingEchidna       test/echidna/assertion/vesting/VestingEchidna.sol       --config test/echidna/assertion/vesting/config.yaml`
- `Launchpad`   -> `echidna --contract LaunchpadEchidna     test/echidna/assertion/launchpad/LaunchpadEchidna.sol   --config test/echidna/assertion/launchpad/config.yaml`


# Run forge tests

`forge test`

#
#
#
# Generate new echidna transactions seed

`--rpc-url http://localhost:7545` is Ganace localdeployment.

It is important that before executing these scripts to use `private key` from Ganache in thoe scripts. 
Update this value in each script: 
` vm.startBroadcast(PRIVATE_KEY);`


- `Staking` -> `forge script --broadcast script/staking/StakingEchidnaTestScript.sol  --tc StakingEchidnaTestScript --json --rpc-url http://localhost:7545`
- `Vesting` -> `forge script --broadcast script/vesting/VestingEchidnaTestScript.sol   --tc VestingEchidnaTestScript  --json --rpc-url HTTP://127.0.0.1:7545`
- `Launchpad` -> `forge script --broadcast script/launchpad/LaunchpadEchidnaTestScript.s.sol  --tc LaunchpadEchidnaTestScript --json --rpc-url http://localhost:7545`

Transactions sed json is generated in `broadcast` folder.


- `foundry2echidna` -> https://github.com/ChmielewskiKamil/foundry2echidna
Now to transaform it to Echidna/Etheno format use
`foundry2echidna --input-path run-latest.json --output-path  run-latest-etheno-echidna.json`

Last step is to find out StableToken and contract address in that file and update Echidna test with new address, where tokens will be attached. 
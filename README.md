# Hybrid Assets

Hybrid assets are a mixture between Fungible assets and Digital assets on the Aptos blockchain.
It takes inspiration from ERC/DN-404, but taking advantage of things that can only be done on
the Aptos blockchain.

## How does it work?


There are two ways to transfer the assets:
1. As a fungible asset (Fungible token)
2. As a digital asset (Non-fungible token)

### Transferring as a fungible asset (Fungible token)

When a user transfers fungible assets via a DEX or just by transferring,
NFTs will be burned or minted based on the number of fungible tokens held by the
account.  When the account, has a "full NFT" worth of fungible tokens, it mints to
the account.  Whenever an account drops below a "full NFT" worth of fungible tokens
an NFT is burned from the account.

This applies also when trading the fungible token on a DEX.  As a builder, remember
to add the ability to skip NFT minting on liquidity pools, or you will limit the 
amount able to be traded on a DEX.

### Transferring as a digital asset (NFT)

When a user transfers the digital asset, the fungible tokens automatically get
withdrawn from the account as well.  This ensures the property that the number of
fungible tokens for a "full NFT" is always in the user's wallet.

This applies when also trading the NFT on a NFT marketplace

### Reveals

Reveals are up to the builder of the hybrid collection.

## Example

There is an example that keeps track of all of the NFTs directly.

## NFT Marketplaces and wallets

As there is no dynamic dispatch on object transfer, take a look at the NFT utils for how to handle it at a contract level.

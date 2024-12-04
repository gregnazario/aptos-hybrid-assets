#[test_only]
module hybrid_address::hybrid_test {

    use std::option;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::token;
    use hybrid_address::package_manager;
    use hybrid_address::hybrid::{Self, HybridToken, create_test_collection, reveal, is_revealed};

    const NUM_TOTAL_NFTS: u64 = 100;
    const NUM_TOKENS_PER_NFT: u64 = 1;
    const DECIMALS: u8 = 6;

    #[test(
        aptos_framework = @0x1,
        hybrid = @hybrid_address,
        creator = @0xDEADBEEF,
        user = @0xA1337,
        user2 = @0xB1337
    )]
    fun test_flow(
        aptos_framework: &signer,
        hybrid: &signer,
        creator: &signer,
        user: &signer,
        user2: &signer
    ) {
        package_manager::initialize_for_test(hybrid);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins = coin::mint(1000000000, &mint_cap);
        let user_address = signer::address_of(user);
        aptos_account::create_account(user_address);
        coin::register<AptosCoin>(user);
        coin::deposit(user_address, coins);
        let coins = coin::mint(1000000000, &mint_cap);
        let user2_address = signer::address_of(user2);
        aptos_account::create_account(user2_address);
        coin::register<AptosCoin>(user2);
        coin::deposit(user2_address, coins);

        let (collection_obj, reveal_ref) = create_test_collection(creator, false);

        let one_nft = NUM_TOKENS_PER_NFT * math64::pow(10, (DECIMALS as u64));
        let total_fa = NUM_TOTAL_NFTS * one_nft;

        // Mint entirety to collection
        hybrid::mint_to_treasury(
            creator,
            collection_obj,
            total_fa,
        );
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa, 100);

        // Send user under the amount to mint, treasury should be deducted, no NFT minted
        hybrid::send_from_treasury_to_user(creator, collection_obj, user_address, one_nft - 1);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - one_nft + 1, 101);
        assert!(vector::is_empty(&hybrid::get_nfts_by_owner(user_address, collection_obj)), 102);

        // Send the last one to mint, one NFT should be minted
        hybrid::send_from_treasury_to_user(creator, collection_obj, user_address, 1);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - one_nft, 103);
        assert!(vector::length(&hybrid::get_nfts_by_owner(user_address, collection_obj)) == 1, 104);

        // Let's ensure that minting a lot can happen
        hybrid::send_from_treasury_to_user(creator, collection_obj, user_address, one_nft * 5);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - (one_nft * 6), 105);
        let user_tokens = hybrid::get_nfts_by_owner(user_address, collection_obj);
        assert!(vector::length(&user_tokens) == 6, 106);

        // Reveal one
        let token_1_address = vector::pop_back(&mut user_tokens);
        let token_1 = object::address_to_object<HybridToken>(token_1_address);
        let token_1_before_name = token::name(token_1);
        assert!(!is_revealed(token_1), 107);
        reveal(
            &reveal_ref,
            token_1,
            option::some(string::utf8(b"hello")),
            option::none(),
            option::none(),
            true
        );
        assert!(is_revealed(token_1), 107);
        let token_1_after_name = token::name(token_1);
        assert!(token_1_before_name != token_1_after_name, 107);

        // Transfer NFT elsewhere
        let user2_address = signer::address_of(user2);
        hybrid::transfer(user, token_1, user2_address);
        assert!(object::owner(token_1) == user2_address, 109);
        assert!(primary_fungible_store::balance(user_address, collection_obj) == one_nft * 5, 110);
        assert!(primary_fungible_store::balance(user2_address, collection_obj) == one_nft, 111);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}

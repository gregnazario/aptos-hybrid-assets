#[test_only]
module hybrid_example_addr::example_test {

    use std::signer;
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin;
    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::token;
    use hybrid_example_addr::hybrid_example;
    use hybrid_example_addr::hybrid_example::initialize_for_test;
    use hybrid_address::hybrid::{Self, HybridToken};

    const NUM_TOTAL_NFTS: u64 = 100;
    /// 10k full tokens needed for a single NFT
    const NUM_TOKENS_PER_NFT: u64 = 10;
    /// 1% royalties on NFT marketplaces (can be adjusted later)
    const ROYALTY_NUMERATOR: u64 = 1;
    const ROYALTY_DENOMINATOR: u64 = 1000;
    const DECIMALS: u8 = 8;

    #[test(
        aptos_framework = @0x1,
        hybrid = @hybrid_address,
        royalty_addr = @0x11111111,
        example_addr = @hybrid_example_addr,
        user = @0xA1337,
        user2 = @0xB1337
    )]
    fun test_flow(
        aptos_framework: &signer,
        hybrid: &signer,
        royalty_addr: &signer,
        example_addr: &signer,
        user: &signer,
        user2: &signer
    ) {
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
        aptos_account::create_account(signer::address_of(royalty_addr));
        coin::register<AptosCoin>(royalty_addr);

        let collection_obj = initialize_for_test(aptos_framework, hybrid, example_addr);
        let one_nft = NUM_TOKENS_PER_NFT * math64::pow(10, (DECIMALS as u64));
        let total_fa = NUM_TOTAL_NFTS * one_nft;

        // Mint entirety to collection
        hybrid::mint_to_treasury(
            example_addr,
            collection_obj,
            total_fa,
        );
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa, 100);

        // Send user under the amount to mint, treasury should be deducted, no NFT minted
        hybrid::send_from_treasury_to_user(example_addr, collection_obj, user_address, one_nft - 1);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - one_nft + 1, 101);
        assert!(vector::is_empty(&hybrid::get_nfts_by_owner(user_address, collection_obj)), 102);

        // Send the last one to mint, one NFT should be minted
        hybrid::send_from_treasury_to_user(example_addr, collection_obj, user_address, 1);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - one_nft, 103);
        assert!(vector::length(&hybrid::get_nfts_by_owner(user_address, collection_obj)) == 1, 104);

        // Let's ensure that minting a lot can happen
        hybrid::send_from_treasury_to_user(example_addr, collection_obj, user_address, one_nft * 5);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - (one_nft * 6), 105);
        let user_tokens = hybrid::get_nfts_by_owner(user_address, collection_obj);
        assert!(vector::length(&user_tokens) == 6, 106);

        // Reveal one
        let token_1_address = vector::pop_back(&mut user_tokens);
        let token_1 = object::address_to_object<HybridToken>(token_1_address);
        let token_1_before_name = token::name(token_1);
        hybrid_example::reveal_for_test(user, token_1);
        let token_1_after_name = token::name(token_1);
        assert!(token_1_before_name != token_1_after_name, 107);

        // Reveal multiple
        let user_token_objs = vector::map(user_tokens, |token| {
            object::address_to_object<HybridToken>(token_1_address)
        });

        let before_names = vector::map_ref(&user_token_objs, |token| {
            token::name(*token)
        });

        hybrid_example::reveal_many_for_test(user, user_tokens);

        let after_names = vector::map_ref(&user_token_objs, |token| {
            token::name(*token)
        });

        for (i in 0..5) {
            assert!(vector::borrow(&before_names, i) == vector::borrow(&after_names, i), 108);
        };

        // Transfer NFT elsewhere
        let user2_address = signer::address_of(user2);
        hybrid::transfer(user, token_1, user2_address);
        assert!(object::owner(token_1) == user2_address, 109);
        assert!(primary_fungible_store::balance(user_address, collection_obj) == one_nft * 5, 110);
        assert!(primary_fungible_store::balance(user2_address, collection_obj) == one_nft, 111);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(
        aptos_framework = @0x1,
        hybrid = @hybrid_address,
        _royalty_addr = @0x11111111,
        example_addr = @hybrid_example_addr,
        user = @0xA1337,
        user2 = @0xB1337
    )]
    fun test_allowlist(
        aptos_framework: &signer,
        hybrid: &signer,
        _royalty_addr: &signer,
        example_addr: &signer,
        user: &signer,
        user2: &signer
    ) {
        let collection_obj = initialize_for_test(aptos_framework, hybrid, example_addr);
        let one_nft = NUM_TOKENS_PER_NFT * math64::pow(10, (DECIMALS as u64));
        let total_fa = NUM_TOTAL_NFTS * one_nft;

        // Mint entirety to collection
        hybrid::mint_to_treasury(
            example_addr,
            collection_obj,
            total_fa,
        );
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa, 100);

        // Send user under the amount to mint
        let user_address = signer::address_of(user);
        hybrid::send_from_treasury_to_user(example_addr, collection_obj, user_address, 5 * one_nft);
        let balance = hybrid::get_treasury_balance(collection_obj);
        assert!(balance == total_fa - (one_nft * 5), 101);
        assert!(vector::length(&hybrid::get_nfts_by_owner(user_address, collection_obj)) == 5, 102);

        // IMPORTANT, do not send from treasury directly to an allowlisted pool
        let user2_address = signer::address_of(user2);
        hybrid_example::add_to_allowlist(example_addr, object::convert(collection_obj), vector[user2_address]);

        // Let's ensure minting doesn't happen
        primary_fungible_store::transfer(user, collection_obj, user2_address, one_nft);
        let user_tokens = hybrid::get_nfts_by_owner(user_address, collection_obj);
        assert!(vector::length(&user_tokens) == 4, 106);
        let user2_tokens = hybrid::get_nfts_by_owner(user2_address, collection_obj);
        assert!(vector::length(&user2_tokens) == 0, 106);

        // Transfer it back to ensure that there's no burn
        primary_fungible_store::transfer(user2, collection_obj, user_address, one_nft);
        let user_tokens = hybrid::get_nfts_by_owner(user_address, collection_obj);
        assert!(vector::length(&user_tokens) == 5, 106);
        let user2_tokens = hybrid::get_nfts_by_owner(user2_address, collection_obj);
        assert!(vector::length(&user2_tokens) == 0, 106);

        // Note removal from allowlist will cause bad behavior if they don't have NFTs, but that's fine... we can make ways to forcefully remove NFTs to sync
        hybrid_example::remove_from_allowlist(example_addr, object::convert(collection_obj), vector[user2_address]);

        // Let's ensure minting does happen
        primary_fungible_store::transfer(user, collection_obj, user2_address, one_nft);
        let user_tokens = hybrid::get_nfts_by_owner(user_address, collection_obj);
        assert!(vector::length(&user_tokens) == 4, 106);
        let user2_tokens = hybrid::get_nfts_by_owner(user2_address, collection_obj);
        assert!(vector::length(&user2_tokens) == 1, 106);
    }

    #[test(aptos_framework = @0x1, hybrid = @hybrid_address, example_addr = @hybrid_example_addr)]
    #[expected_failure(abort_code = 131077, location = aptos_framework::fungible_asset)]
    fun test_over_mint(
        aptos_framework: &signer,
        hybrid: &signer,
        example_addr: &signer
    ) {
        let collection_obj = initialize_for_test(aptos_framework, hybrid, example_addr);
        let total_fa = NUM_TOKENS_PER_NFT * NUM_TOTAL_NFTS * math64::pow(10, (DECIMALS as u64));

        // Mint entirety to collection
        hybrid::mint_to_treasury(
            example_addr,
            collection_obj,
            total_fa + 1,
        );
    }
}

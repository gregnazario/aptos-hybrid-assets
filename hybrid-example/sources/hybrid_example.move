/// Hybrid Example
///
/// This randomly chooses between 6 different NFTs to reveal.
module hybrid_example_addr::hybrid_example {

    use std::option;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::debug::print;
    use aptos_std::string_utils;
    use aptos_std::table::{Self, Table};
    use aptos_framework::function_info;
    use aptos_framework::fungible_asset::{Self, FungibleAsset};
    use aptos_framework::object::{Self, Object, ExtendRef, ConstructorRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::randomness;
    use aptos_token_objects::token;
    use hybrid_address::hybrid::{Self, RevealRef, HybridToken, HybridCollection};
    #[test_only]
    use hybrid_address::package_manager;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ExampleHybrid has key {
        extend_ref: ExtendRef,
        reveal_ref: RevealRef,
        allowlisted_pools: Table<address, u8>,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct RevealStageMetadata has key {
        /// Name of the NFT
        name_prefix: String,
        /// Description of the NFT
        nft_description: String,
        /// Base URI for the NFT.
        /// If dynamic, the full NFT URI is constructed as: nft_uri = nft_base_uri + token_id + nft_uri_extension.
        nft_base_uri: String,
        /// Extension of the NFT, this is concatenated to the token ID to get the URI e.g. .png
        nft_uri_extension: String,
    }

    /// Caller is not owner of collection
    const E_NOT_OWNER: u64 = 1;
    /// Caller is not owner of token
    const E_NOT_OWNER_TOKEN: u64 = 2;
    /// Pool is not allowlisted to trade
    const E_NOT_ALLOWED_POOL: u64 = 3;
    /// NFT already revealed
    const E_ALREADY_REVEALED: u64 = 4;

    /// Maximum number of NFTs for randomness
    const MAX_COMBINATIONS: u64 = 6;

    const COLLECTION_NAME: vector<u8> = b"Hybrid Example";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Hybrid Example Collection";
    const COLLECTION_URI: vector<u8> = b"https://raw.githubusercontent.com/gregnazario/aptos-hybrid-assets/refs/heads/main/hybrid-example/images/mystery.jpeg";
    const HIDDEN_NAME: vector<u8> = b"Mystery Box";
    const HIDDEN_URI: vector<u8> = b"https://raw.githubusercontent.com/gregnazario/aptos-hybrid-assets/refs/heads/main/hybrid-example/images/mystery.jpeg";
    const HIDDEN_DESCRIPTION: vector<u8> = b"Reveal to figure out what it will be!";

    const FA_NAME: vector<u8> = b"Example Hybrid Coin";
    const FA_SYMBOL: vector<u8> = b"HYBRID";
    const DECIMALS: u8 = 8;
    const FA_ICON_URL: vector<u8> = b"https://raw.githubusercontent.com/gregnazario/aptos-hybrid-assets/refs/heads/main/hybrid-example/images/coin.jpeg";
    const FA_PROJECT_URL: vector<u8> = b"https://github.com/gregnazario/aptos-hybrid-assets/tree/main/hybrid-example";

    const NUM_TOTAL_NFTS: u64 = 100;
    const NUM_TOKENS_PER_NFT: u64 = 10;
    const ROYALTY_NUMERATOR: u64 = 1;
    const ROYALTY_DENOMINATOR: u64 = 1000;
    const ROYALTY_ADDRESS: address = @hybrid_example_addr;

    const MODULE_NAME: vector<u8> = b"hybrid_example";
    const WITHDRAW_NAME: vector<u8> = b"withdraw";
    const DEPOSIT_NAME: vector<u8> = b"deposit";

    /// Create this example collection, there should only be one allowed in this example
    entry fun create(
        caller: &signer,
    ) {
        create_inner(caller);
    }

    #[test_only]
    /// Create the collection for a test scenario
    fun create_for_test(
        caller: &signer,
    ): ConstructorRef {
        create_inner(caller)
    }

    inline fun create_inner(caller: &signer): ConstructorRef {
        // For some reason, this cannot be deployed to an object
        authorize_admin(caller);

        let module_name = string::utf8(MODULE_NAME);
        let withdraw_name = string::utf8(WITHDRAW_NAME);
        let deposit_name = string::utf8(DEPOSIT_NAME);

        let deposit_function = function_info::new_function_info(
            caller,
            module_name,
            deposit_name
        );

        let withdraw_function = function_info::new_function_info(
            caller,
            module_name,
            withdraw_name
        );

        let constructor_ref = hybrid::create(
            caller,
            string::utf8(COLLECTION_NAME),
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_URI),
            string::utf8(HIDDEN_NAME),
            string::utf8(HIDDEN_URI),
            string::utf8(HIDDEN_DESCRIPTION),
            NUM_TOTAL_NFTS,
            NUM_TOKENS_PER_NFT,
            ROYALTY_NUMERATOR,
            ROYALTY_DENOMINATOR,
            ROYALTY_ADDRESS,
            false,
            string::utf8(FA_NAME),
            string::utf8(FA_SYMBOL),
            DECIMALS,
            string::utf8(FA_ICON_URL),
            string::utf8(FA_PROJECT_URL),
            option::some(withdraw_function),
            option::some(deposit_function),
        );
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);
        let reveal_ref = hybrid::generate_reveal_ref(&constructor_ref);
        move_to(&object_signer, ExampleHybrid {
            extend_ref,
            reveal_ref,
            allowlisted_pools: table::new(),
        });

        move_to(&object_signer, RevealStageMetadata {
            name_prefix: string::utf8(b"Revealed Example "),
            nft_description: string::utf8(b"A revealed example"),
            nft_base_uri: string::utf8(
                b"https://raw.githubusercontent.com/gregnazario/aptos-hybrid-assets/refs/heads/main/hybrid-example/images/"
            ),
            nft_uri_extension: string::utf8(b".jpeg"),
        });

        constructor_ref
    }

    inline fun authorize_admin(caller: &signer): address {
        let caller_address = signer::address_of(caller);
        assert!(caller_address == @hybrid_example_addr, E_NOT_OWNER);
        caller_address
    }

    /// Allowlist allows skipping over minting
    public entry fun add_to_allowlist(
        caller: &signer,
        collection: Object<ExampleHybrid>,
        addresses: vector<address>
    ) acquires ExampleHybrid {
        authorize_admin(caller);

        let collection_address = object::object_address(&collection);
        let hybrid = borrow_global_mut<ExampleHybrid>(collection_address);
        vector::for_each(addresses, |address| {
            table::upsert(&mut hybrid.allowlisted_pools, address, 1);
        })
    }

    public entry fun remove_from_allowlist(
        caller: &signer,
        collection: Object<ExampleHybrid>,
        addresses: vector<address>
    ) acquires ExampleHybrid {
        authorize_admin(caller);

        let collection_address = object::object_address(&collection);
        let hybrid = borrow_global_mut<ExampleHybrid>(collection_address);
        vector::for_each(addresses, |address| {
            if (table::contains(&hybrid.allowlisted_pools, address)) {
                table::remove(&mut hybrid.allowlisted_pools, address);
            }
        })
    }

    /// Transfer provides functionality used for dynamic dispatch
    ///
    /// This will not be called by any other functions.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ) acquires ExampleHybrid {
        let store_address = object::object_address(&store);
        let metadata = fungible_asset::metadata_from_asset(&fa);
        let owner_address = object::owner(store);

        let primary_store_address =
            primary_fungible_store::primary_store_address_inlined(owner_address, metadata);

        let metadata_address = object::object_address(&metadata);
        let example = borrow_global<ExampleHybrid>(metadata_address);
        print(
            &string_utils::format3(
                &b"{}-{}-{}",
                owner_address,
                store_address,
                table::contains(&example.allowlisted_pools, owner_address)
            )
        );
        // Primary stores are not pools usually
        if (primary_store_address != store_address) {
            print(&string::utf8(b"Not a priimary"));
            assert!(!table::contains(&example.allowlisted_pools, owner_address), E_NOT_ALLOWED_POOL);
        } else {
            // If it's a primary, we skip over minting, it's a pool
            print(&string::utf8(b"Primary"));
            if (table::contains(&example.allowlisted_pools, owner_address)) {
                print(&string::utf8(b"Allowlisted"));
                return hybrid::deposit_without_mint(&example.reveal_ref, store, fa, transfer_ref)
            }
        };

        // To leave for adding extra things later
        hybrid::deposit(store, fa, transfer_ref)
    }

    /// Transfer provides functionality used for dynamic dispatch
    ///
    /// This will not be called by any other functions.
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &fungible_asset::TransferRef
    ): FungibleAsset acquires ExampleHybrid {
        let metadata = fungible_asset::store_metadata(store);
        let metadata_address = object::object_address(&metadata);
        let example = borrow_global<ExampleHybrid>(metadata_address);
        let owner_address = object::owner(store);

        // Don't burn from pools, they shouldn't have them
        if (table::contains(&example.allowlisted_pools, owner_address)) {
            print(&b"Withdraw without burn");
            return hybrid::withdraw_without_burn(&example.reveal_ref, store, amount, transfer_ref)
        };

        hybrid::withdraw(store, amount, transfer_ref)
    }

    #[test_only]
    /// This must be test only or the randomness will be biasable
    public fun reveal_for_test(
        caller: &signer,
        token: Object<HybridToken>
    ) acquires ExampleHybrid, RevealStageMetadata {
        reveal_inner(caller, token);
    }

    #[test_only]
    /// This must be test only or the randomness will be biasable
    public fun reveal_many_for_test(
        caller: &signer,
        tokens: vector<address>
    ) acquires ExampleHybrid, RevealStageMetadata {
        reveal_many(caller, tokens);
    }

    #[randomness]
    /// Reveal MUST be non-public, or it will allow for people to perform attacks against the randomness
    /// This one will NOT fail if the token is already revealed
    entry fun reveal(caller: &signer, token: Object<HybridToken>) acquires ExampleHybrid, RevealStageMetadata {
        reveal_inner(caller, token);
    }

    #[randomness]
    /// Reveal MUST be non-public, or it will allow for people to perform attacks against the randomness
    /// This one will NOT fail if a token is already revealed
    entry fun reveal_many(caller: &signer, tokens: vector<address>) acquires ExampleHybrid, RevealStageMetadata {
        vector::for_each(tokens, |token| {
            let token_object = object::address_to_object(token);
            reveal_inner(caller, token_object);
        })
    }

    fun reveal_inner(caller: &signer, token: Object<HybridToken>) acquires ExampleHybrid, RevealStageMetadata {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(token, caller_address), E_NOT_OWNER_TOKEN);

        let collection_object = token::collection_object(token);
        let collection_address = object::object_address(&collection_object);

        let example = borrow_global<ExampleHybrid>(collection_address);
        let reveal_data = borrow_global<RevealStageMetadata>(collection_address);

        // This scheme, is to randomly choose ANY of the possible outcomes.  This does not prevent against duplicates.
        let roll_number = randomness::u64_range(0, MAX_COMBINATIONS);
        let name = reveal_data.name_prefix;
        string::append_utf8(
            &mut name,
            *string::bytes(&string_utils::to_string_with_integer_types(&roll_number))
        );

        let uri = reveal_data.nft_base_uri;
        string::append(&mut uri, string_utils::to_string(&roll_number));
        string::append(&mut uri, reveal_data.nft_uri_extension);

        hybrid::reveal(
            &example.reveal_ref,
            token,
            option::some(name),
            option::none(),
            option::some(uri),
            false,
        );
    }


    /// Sets data for a simple reveal stage
    entry fun set_stage_reveal(
        caller: &signer,
        collection: Object<HybridCollection>,
        name_prefix: String,
        nft_description: String,
        nft_base_uri: String,
        nft_uri_extension: String,
    ) acquires ExampleHybrid, RevealStageMetadata {
        let caller_address = signer::address_of(caller);
        assert!(object::owns(collection, caller_address), E_NOT_OWNER);
        let collection_address = object::object_address(&collection);

        if (nft_uri_extension != string::utf8(b"")) {
            let base_uri_length = string::length(&nft_base_uri);

            if (string::sub_string(&nft_base_uri, base_uri_length - 1, base_uri_length)
                != string::utf8(b"/")) {
                string::append(&mut nft_base_uri, string::utf8(b"/"));
            };
            if (string::sub_string(&nft_uri_extension, 0, 1) != string::utf8(b".")) {
                string::insert(&mut nft_uri_extension, 0, string::utf8(b"."));
            };
        };

        // To make things nicer, make sure nft name ends in a space
        if (name_prefix != string::utf8(b"")) {
            let length = string::length(&name_prefix);
            if (string::sub_string(&name_prefix, length - 1, length) != string::utf8(b" ")) {
                string::append(&mut name_prefix, string::utf8(b" "))
            }
        };

        if (!exists<RevealStageMetadata>(collection_address)) {
            let object_controller = borrow_global<ExampleHybrid>(collection_address);
            let collection_signer = &object::generate_signer_for_extending(&object_controller.extend_ref);
            move_to(collection_signer, RevealStageMetadata {
                name_prefix,
                nft_description,
                nft_base_uri,
                nft_uri_extension,
            })
        } else {
            let reveal_metadata = borrow_global_mut<RevealStageMetadata>(collection_address);
            reveal_metadata.name_prefix = name_prefix;
            reveal_metadata.nft_description = nft_description;
            reveal_metadata.nft_base_uri = nft_base_uri;
            reveal_metadata.nft_uri_extension = nft_uri_extension;
        }
    }

    #[test_only]
    public fun initialize_for_test(
        aptos_framework: &signer,
        hybrid: &signer,
        ama: &signer
    ): Object<HybridCollection> {
        // Initalize randomness
        randomness::initialize_for_testing(aptos_framework);

        // Initialize hybrid contract state
        package_manager::initialize_for_test(hybrid);

        // Create collection
        let collection_constructor_ref = create_for_test(ama);
        object::object_from_constructor_ref<HybridCollection>(&collection_constructor_ref)
    }
}
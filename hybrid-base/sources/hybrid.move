/// # Hybrid Assets
///
/// Simliar to Dn404, it has a fungible token associated with a non-fungible token
///
/// ## How does it work?
///
/// Hybrid assets use a paired fungible token (FT) and non-fungible token (NFT) collection.  There is a specific ratio between the
/// FT and the NFT.  When the FT is transferred up to a certain amount (which is
/// configurable), NFTs will be minted to an account according to the ratio.  It will also then burn the NFTs from the
/// account that transferred them out.
///
/// However, a user can still transfer a NFT directly to the other user, and the FT will go along with it.
///
/// ## Why mint and burn the NFTs?
///
/// This provides a fun mechanic, where when the NFT is burned, the user can "re-roll" or reveal the NFT according to
/// the project's rules.  This would be in a wrapping contract around this one.  Each time the NFT is transferred it will
/// "hide" the NFT with a hidden image, and the NFT can be revealed later.
///
/// ### Transferring Fungible Tokens (FTs) example
///
/// For example, Let's assume the ratio is 1 full FT to 1 full NFT. When 1 full FT is transferred
/// from Alice to Bob, 1 NFT will be burned from Alice, and 1 NFT will be minted to Bob.  But, let's say Bob transfers
/// back to Alice 1/2 of a FT.  When that half FT is transferred, 1 NFT will be burned from Bob, but no NFT will
/// be minted to Alice.  Only when Alice receives another 1/2 of a token from any source, will one be minted in her account.
///
/// ### Transferring Non-Fungible Tokens (NFTs) example
///
/// For example,  Let's assume the ratio is 1 full FT to 1 full NFT. let's also assume Alice has 1 NFT, and wants to
/// transfer it to Bob.  When Alice transfers the NFT to Bob, 1 FT will also be transferred to Bob.  This will not cause
/// burning or minting of the NFTs.
///
/// Take a look at `hybrid-example` for a full example of how to use this module.
///
/// ## Deploying
/// NOTE: This must be deployed as a Resource account, but should be able to be used by any account
///
/// To deploy simply run the following Aptos CLI command:
/// ```bash
/// export HYBRID_DEPLOYER="your-cli-profile-name-here"
/// export SEED="Any-value"
/// aptos move create-resource-account-and-publish-package --address-name hybrid_address --seed $SEED --named-addresses deployer=$HYBRID_DEPLOYER --profile $HYBRID_DEPLOYER --max-gas 50000 --assume-yes
/// ```
///
/// ### Creating a Hybrid Collection
///
/// To create a Hybrid Collection, you will need to call the `create` function.  This will create a collection object
/// that will control the minting and burning of the NFTs.  It will also create the fungible asset that will be used
/// to mint and burn the NFTs.
///
/// Note that you will want to write a wrapping contract that handles any special logic around revealing the NFTs.
///
/// ## User and Admin Flows
///
/// ### Admin flow
/// 1. Create a Hybrid Collection
/// 2. Mint fungible tokens to the treasury
/// 3. Transfer fungible tokens to users
/// 4. Let users have fun
/// 5. Change royalties and other features later, should be addressable from the wrapping contract
///
/// ### User flow
///
/// 1. Transfer fungible tokens to another user -> This allows for minting of NFTs and rerolls
///   - This includes via a DEX or other mechanism
/// 2. Transfer non-fungible tokens to another user -> This allows for direct transfer of NFTs with FTs
///   - This includes via an NFT marketplace
/// 3. Reveal NFTs -> This allows for revealing the NFTs
/// 4. When a user wants to SAVE an NFT, they must transfer it to another wallet.  The removal of FTs from an account
///    may cause their NFTs to be burned, and they will need to use caution with it.
///
/// #### Example flow
///
/// 1. User goes to a DEX and swaps for 1 full FT
/// 2. User gets minted a mystery NFT
/// 3. User goes to a frontend elsewhere and reveals the NFT
/// 4. User gets a revealed NFT and decides that they don't like it
/// 5. User swaps away their full FT, and swaps another full FT, and gets another mystery NFT
/// 6. User reveals, and finds an NFT they like
/// 7. User goes to a marketplace and sells the NFT or transfers it to another wallet or user
///
/// ## Other functionality integrations
///
/// ### DEXs
///
/// - Decentralized exchanges must support dispatchable fungible assets.  It's used for the minting and burning specifically.
/// - Because of the dynamic dispatch, this is probably the least amount of work here.
/// - Contracts built on top of this may choose to skip NFT minting and burning for the DEX addresses
///
/// ### NFT Marketplaces
///
/// - NFT marketplaces must use the `hybrid::transfer` function to ensure that the FTs are transferred with the NFTs
/// - Normal transfer is disabled
/// - Check out `nft_utils` for an example of how to handle it within Move code
///
/// ### Wallets
///
/// - Similar to NFT marketplaces, wallets must use the `hybrid::transfer` function to ensure that the FTs are transferred with the NFTs
/// - Display functionalities are not yet well defined, but they should automatically show up as both FT and NFTs
///
/// ### Reveal Contracts
///
/// - Reveal contracts must call the `hybrid::deposit_with_ref` and `hybrid::withdraw_with_ref` functions to ensure that the minting and burning of NFTs works correctly
/// - Reveal contracts must also call the `hybrid::reveal` function to ensure that the NFTs are revealed correctly
///
/// ## Technical Details
///
/// The contract is run on a resource account, specifically so that it can use the functions in dispatchable overrides.
/// At the time of this writing, you must have the signer of the account that contains the dispatchable function.
///
/// When creating a collection, a unique object will be created, which will be the creator and controller of the collection.
/// This is later referred to as the `controller`.  The controller will have the ability to mint and burn the NFTs during
/// FT transfers.  It's imperative that the collection is ALWAYS owned by the `controller` to ensure that the mint, burn
/// and transfer functionalities work correctly.
///
/// The collection will have a fungible asset associated with it, which will be used to mint and burn the NFTs.  The fungible
/// token has everything configurable, and can be fully customized by the calling contract.  A calling contract will want
/// to call `hybrid::deposit_with_ref` and `hybrid::withdraw_with_ref` to ensure that all of the mint, burn, and transfer
/// functions work properly.
///
/// The collection will also have a `HybridConfig` object associated with it, which will store the configuration of the
/// collection.  This includes the number of subtokens per NFT, the number of NFTs in the supply, the name, description, and
/// URI of the NFTs, and whether or not the NFTs will have property maps.  The property maps are optional for builders who
/// want to use them rather than offchain information.
///
/// The NFT addresses will be stored in a `HybridOwnershipData` object, which will be attached to the collection.  This will allow
/// for easy access to the NFTs of a user, and will allow for easy transfer of the NFTs.  This is specifically to know
/// how many NFTs to mint or burn at any time.  As a result, secondary stores are NOT allowed to own NFTs, to prevent
/// NFTs from being transferred ownership in a way that would break the invariant that the FT to NFTs have a set ratio.
///
/// Any downstream reveal functions, must have a reveal ref stored, and must be called with the reveal ref to ensure that
/// reveal functionality actually changes the underlying NFTs.
///
module hybrid_address::hybrid {
    use std::bcs;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::math64;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event::emit;
    use aptos_framework::function_info::{Self, FunctionInfo};
    use aptos_framework::fungible_asset::{Self, Metadata, FungibleAsset, FungibleStore};
    use aptos_framework::object::{Self, ExtendRef, TransferRef, ConstructorRef, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection::{Self, Collection};
    use aptos_token_objects::property_map;
    use aptos_token_objects::royalty;
    use aptos_token_objects::token::{Self, Token};
    use hybrid_address::package_manager;

    /// Name of the hybrid object for address derivation
    const DATA_OBJ_NAME: vector<u8> = b"hybridUserData";

    /// Mint event label
    const MINT: vector<u8> = b"mint";

    /// Burn event label
    const BURN: vector<u8> = b"burn";

    /// Reveal event label
    const REVEAL: vector<u8> = b"reveal";

    /// Not enough FA to transfer
    const E_NOT_ENOUGH_FA: u64 = 1;

    /// Deployer of contract must for now create hybrids
    const E_NOT_DEPLOYER: u64 = 2;

    /// Only owner of object can mint new FAs
    const E_NOT_COLLECTION_OWNER: u64 = 3;

    /// Only owner can modify or transfer NFTs
    const E_NOT_OWNER: u64 = 4;

    /// Fungible store does not exist
    const E_STORE_DOESNT_EXIST: u64 = 5;

    /// NFT not found
    const E_NFT_NOT_FOUND: u64 = 6;

    /// NFT reveal not yet enabled
    const E_REVEAL_NOT_ENABLED: u64 = 7;

    /// NFT already revealed
    const E_ALREADY_REVEALED: u64 = 8;

    /// NFT reveal type incorrectly set by creator
    const E_INVALID_REVEAL_TYPE: u64 = 9;

    /// Reveal ref is invalid
    const E_INVALID_REVEAL_REF: u64 = 10;

    /// Cannot generate reveal ref for object
    const E_INVALID_OBJECT_FOR_REVEAL_REF: u64 = 11;

    /// Length mismatch between input vectors
    const E_LENGTH_MISMATCH: u64 = 12;

    /// NFT not yet revealed
    const E_NOT_YET_REVEALED: u64 = 13;
    /// Function not implemented
    const E_NOT_IMPLEMENTED: u64 = 14;

    /// Object being transferred is not a hybrid token
    const E_NOT_HYBRID_TOKEN: u64 = 14;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// ObjectController keeps track of the ability to modify the object
    struct ObjectController has key {
        /// ExtendRef allows for getting the signer of the object
        extend_ref: ExtendRef,
        /// TransferRef allows for sending the object to a different owner
        transfer_ref: Option<TransferRef>
    }

    // -- Structs on the collection / Fungible asset metadata -- //

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Controls the collection for minting and burning
    struct HybridCollection has key {
        /// The object that will forever own the collection
        controller_address: address,
        /// MutatorRef allows for changing the collection details
        collection_mutator_ref: collection::MutatorRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Refs for keeping track of the Fungible Asset, to separate from the ones on the collection
    struct AssetRefs has key {
        /// TransferRef for controlled fungible asset transfers
        transfer_ref: fungible_asset::TransferRef,
        /// For changing the FA's metadata
        mutate_ref: Option<fungible_asset::MutateMetadataRef>,
        /// For changing the FA's royalty
        royalty_mutate_ref: Option<royalty::MutatorRef>,
        /// MintRef allows for minting more fungible assets
        mint_ref: Option<fungible_asset::MintRef>,
        /// BurnRef allows for burning more fungible assets
        burn_ref: Option<fungible_asset::BurnRef>
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Configuration specific to this Hybrid collection
    /// NOTE: This might want to be disconnected from the ObjectGroup for gas purposes
    struct HybridConfig has key {
        /// Number of subtokens (with full decimals) per NFT
        /// This is done here to optimize on doing 10^decimals * num_tokens_per_nft only once
        num_subtokens_per_nft: u64,
        /// Number of NFTs in the supply
        num_supply_nfts: u64,
        /// Name of NFT
        hidden_nft_name: String,
        /// Description of the NFT
        hidden_nft_description: String,
        /// URI of the NFT
        hidden_nft_uri: String,
        /// If set, tokens will have property maps added
        with_properties: bool,
    }

    /// Allows for overriding the reveal functionality
    struct RevealRef has store, drop {
        addr: address
    }

    // -- Events -- //
    #[event]
    /// Event emitted every time there's a Hybrid burn / mint
    struct HybridEvent has store, drop {
        /// Address of the collection object
        collection: address,
        /// Address effected by the event
        address: address,
        /// Type of the event e.g. mint or burn
        type: string::String,
        /// Addresses associated with the event
        nfts: vector<address>
    }

    // -- Structs on the NFT -- //

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// HybridToken handles the burning and mutation of a Token
    struct HybridToken has key {
        /// Mutator ref allows for modifying the metadata of the token at a later time
        mutator_ref: token::MutatorRef,
        /// Burn ref allows for burning the NFT on token transfer
        burn_ref: token::BurnRef,
        /// For modifying the token property map
        token_property_mutator_ref: Option<property_map::MutatorRef>,
        /// Tells if the token is revealed
        revealed: bool,
    }

    // -- Structs on the per user object -- //

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Data about an individual user, to keep deterministic, but also easy to find, it will be attached to the collection
    /// We were using a table, but moved to this as a more scalable solution
    struct HybridOwnershipData has key {
        /// List of all of the NFTs of a user
        nfts: vector<address>,
    }

    /// Generate a RevealRef to add reveal functionality
    public fun generate_reveal_ref(constructor_ref: &ConstructorRef): RevealRef {
        let object_addr = object::address_from_constructor_ref(constructor_ref);
        assert!(exists<HybridCollection>(object_addr), E_INVALID_OBJECT_FOR_REVEAL_REF);

        RevealRef {
            addr: object_addr
        }
    }

    /// Creates a Hybrid collection.  What this does is the following
    /// 1. Creates an object that will control the collection (for minting / burning purposes)
    /// 2. Creates the collection object, and stores associated metadata
    public fun create(
        caller: &signer,
        // Collection inputs
        collection_name: String,
        collection_description: String,
        collection_uri: String,
        // NFT inputs
        hidden_nft_name: String,
        hidden_nft_uri: String,
        hidden_nft_description: String,
        num_supply_nfts: u64,
        num_tokens_per_nft: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_address: address,
        with_properties: bool,
        // FA Inputs
        fa_name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        withdraw_function: Option<FunctionInfo>,
        deposit_function: Option<FunctionInfo>
    ): ConstructorRef {
        // We let anyone call this function
        let resource_account_signer = &package_manager::get_signer();

        // Create a collection owner, owned by the caller, we dedupe on collection name
        let object_name = b"hybrid-";
        vector::append(&mut object_name, *string::bytes(&collection_name));
        let controller_const_ref = &object::create_named_object(caller, object_name);
        let controller_signer = &object::generate_signer(controller_const_ref);
        let controller_extend_ref = object::generate_extend_ref(controller_const_ref);
        let controller_transfer_ref = object::generate_transfer_ref(controller_const_ref);

        move_to(controller_signer, ObjectController {
            extend_ref: controller_extend_ref,
            transfer_ref: option::some(controller_transfer_ref),
        });

        // Create collection
        let collection_constructor = create_collection(
            controller_signer,
            resource_account_signer,
            collection_name,
            collection_description,
            collection_uri,
            hidden_nft_name,
            hidden_nft_uri,
            hidden_nft_description,
            num_supply_nfts,
            num_tokens_per_nft,
            royalty_numerator,
            royalty_denominator,
            royalty_address,
            with_properties,
            fa_name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
            withdraw_function,
            deposit_function
        );

        collection_constructor
    }


    /// create_collection creates the hybrid associated collection
    inline fun create_collection(
        controller_signer: &signer,
        resource_account_signer: &signer,
        // Collection inputs
        collection_name: String,
        collection_description: String,
        collection_uri: String,
        // NFT inputs
        hidden_nft_name: String,
        hidden_nft_uri: String,
        hidden_nft_description: String,
        num_supply_nfts: u64,
        num_tokens_per_nft: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_address: address,
        with_properties: bool,
        // FA Inputs
        fa_name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
        withdraw_function: option::Option<FunctionInfo>,
        deposit_function: option::Option<FunctionInfo>
    ): ConstructorRef {
        let controller_address = signer::address_of(controller_signer);
        let royalty = royalty::create(royalty_numerator, royalty_denominator, royalty_address);

        // Create the collection with the associated data
        let collection_constructor = collection::create_fixed_collection(
            controller_signer,
            collection_description,
            num_supply_nfts,
            collection_name,
            option::some(royalty),
            collection_uri
        );
        let collection_extend_ref = object::generate_extend_ref(&collection_constructor);
        let collection_transfer_ref = object::generate_transfer_ref(&collection_constructor);
        let collection_signer = &object::generate_signer(&collection_constructor);

        // Controller shouldn't separate from owner
        object::disable_ungated_transfer(&collection_transfer_ref);

        // Create a mutator ref for the collection details
        let collection_mutator_ref = collection::generate_mutator_ref(&collection_constructor);

        // Setup FA
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &collection_constructor,
            option::some(
                (one_nft_in_fa(decimals, num_tokens_per_nft) as u128)
                    * (num_supply_nfts as u128)
            ),
            fa_name,
            symbol,
            decimals,
            icon_uri,
            project_uri
        );

        // Setup dynamic dispatch overrides, if not provided, it will use the default overrides
        let withdraw_override = withdraw_function;
        if (!option::is_some(&withdraw_override)) {
            withdraw_override = option::some(
                function_info::new_function_info(
                    resource_account_signer,
                    string::utf8(b"hybrid"),
                    string::utf8(b"withdraw")
                )
            );
        };
        let deposit_override = deposit_function;
        if (!option::is_some(&deposit_override)) {
            deposit_override = option::some(
                function_info::new_function_info(
                    resource_account_signer,
                    string::utf8(b"hybrid"),
                    string::utf8(b"deposit")
                )
            );
        };

        dispatchable_fungible_asset::register_dispatch_functions(
            &collection_constructor,
            withdraw_override,
            deposit_override,
            option::none()
        );

        // Setup Hybrid controller
        let mint_ref = fungible_asset::generate_mint_ref(&collection_constructor);
        let transfer_ref = fungible_asset::generate_transfer_ref(&collection_constructor);
        let burn_ref = fungible_asset::generate_burn_ref(&collection_constructor);
        let mutate_metadata_ref = fungible_asset::generate_mutate_metadata_ref(&collection_constructor);
        let royalty_mutate_ref = royalty::generate_mutator_ref(object::generate_extend_ref(&collection_constructor));

        // Push object controller to the collection object
        move_to(collection_signer, ObjectController {
            extend_ref: collection_extend_ref,
            transfer_ref: option::none() // We don't want to detach the collection from the controller
        });
        move_to(collection_signer, AssetRefs {
            mutate_ref: option::some(mutate_metadata_ref),
            mint_ref: option::some(mint_ref),
            burn_ref: option::some(burn_ref),
            royalty_mutate_ref: option::some(royalty_mutate_ref),
            transfer_ref,
        });
        move_to(collection_signer, HybridCollection {
            controller_address,
            collection_mutator_ref,
        });

        // To make things nicer, make sure nft name ends in a space
        if (hidden_nft_name != string::utf8(b"")) {
            let length = string::length(&hidden_nft_name);
            if (string::sub_string(&hidden_nft_name, length - 1, length) != string::utf8(b" ")) {
                string::append(&mut hidden_nft_name, string::utf8(b" "))
            }
        };

        move_to(collection_signer, HybridConfig {
            num_subtokens_per_nft: one_nft_in_fa(decimals, num_tokens_per_nft),
            num_supply_nfts,
            hidden_nft_name,
            hidden_nft_description,
            hidden_nft_uri,
            with_properties,
        });

        // Add a store to the collection, to store the treasury
        let metadata_object = object::object_from_constructor_ref<Metadata>(&collection_constructor);
        fungible_asset::create_store(&collection_constructor, metadata_object);

        emit(HybridEvent {
            collection: object::address_from_constructor_ref(&collection_constructor),
            address: controller_address,
            type: string::utf8(b"Collection Creation"),
            nfts: vector[]
        });

        collection_constructor
    }

    /// This function replaces [`0x1::object::transfer`], as object transfer had to be disabled, since it doesn't support
    /// dynamic dispatch.  Instead, this function should be used to transfer the NFT.
    ///
    /// Note: Transfer NFT will fail to transfer if you do not have enough FA in your primary fungible store.  If that's
    /// the case, you will need to transfer FA first to the primary store.
    public entry fun transfer<T: key>(
        caller: &signer,
        token: Object<T>,
        receiver: address
    ) acquires ObjectController, AssetRefs, HybridConfig, HybridOwnershipData {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(token, caller_address), E_NOT_OWNER);
        assert!(is_hybrid_token(token), E_NOT_HYBRID_TOKEN);

        // Transfer the NFT
        let token_address = object::object_address(&token);
        let token_object_controller = borrow_global<ObjectController>(token_address);
        let linear_transfer_ref = object::generate_linear_transfer_ref(
            option::borrow(&token_object_controller.transfer_ref)
        );
        object::transfer_with_ref(linear_transfer_ref, receiver);

        // Update user NFT data
        let collection_object = token::collection_object(token);
        let collection_address = object::object_address(&collection_object);
        let sender_hybrid_data = ensure_hybrid_data(collection_address, &caller_address);
        let (exist, index) = vector::index_of(&sender_hybrid_data.nfts, &token_address);
        assert!(exist, E_NFT_NOT_FOUND);
        vector::swap_remove(&mut sender_hybrid_data.nfts, index);


        let receiver_hybrid_data = ensure_hybrid_data(collection_address, &receiver);
        vector::push_back(&mut receiver_hybrid_data.nfts, token_address);

        // Transfer the FAs
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        let hybrid_config = borrow_global<HybridConfig>(collection_address);

        let sender_store = primary_fungible_store::ensure_primary_store_exists(
            caller_address,
            collection_object
        );
        let receiver_store = primary_fungible_store::ensure_primary_store_exists(
            receiver,
            collection_object
        );

        // Note, this bypasses the dynamic dispatch flow
        let fa = fungible_asset::withdraw_with_ref(
            &asset_refs.transfer_ref,
            sender_store,
            hybrid_config.num_subtokens_per_nft
        );
        fungible_asset::deposit_with_ref(&asset_refs.transfer_ref, receiver_store, fa);
    }

    /// Reveals the collection, must have the reveal ref
    public fun reveal(
        reveal_ref: &RevealRef,
        token: Object<HybridToken>,
        new_name: Option<String>,
        new_desc: Option<String>,
        new_uri: Option<String>,
        only_reveal_once: bool,
    ) acquires HybridToken {
        ensure_correct_reveal_ref(reveal_ref, token);
        let token_address = object::object_address(&token);
        let token_controller = borrow_global_mut<HybridToken>(token_address);
        if (only_reveal_once) {
            assert!(!token_controller.revealed, E_ALREADY_REVEALED);
        };

        if (option::is_some(&new_name)) {
            token::set_name(&token_controller.mutator_ref, option::destroy_some(new_name));
        };
        if (option::is_some(&new_desc)) {
            token::set_description(&token_controller.mutator_ref, option::destroy_some(new_desc));
        };
        if (option::is_some(&new_uri)) {
            token::set_uri(&token_controller.mutator_ref, option::destroy_some(new_uri));
        };
        token_controller.revealed = true;

        emit(HybridEvent {
            collection: reveal_ref.addr,
            address: token_address,
            type: string::utf8(REVEAL),
            nfts: vector[token_address]
        })
    }

    /// Sets collection royalty
    public fun set_collection_royalty(
        reveal_ref: &RevealRef,
        collection: Object<HybridCollection>,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_address: address
    ) acquires AssetRefs {
        ensure_correct_reveal_ref_collection(reveal_ref, collection);

        let collection_address = object::object_address(&collection);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        let royalty = royalty::create(royalty_numerator, royalty_denominator, royalty_address);
        royalty::update(option::borrow(&asset_refs.royalty_mutate_ref), royalty);
    }

    /// Updates the URI, can only be called after it is revealed
    public fun update_nft_uri(
        reveal_ref: &RevealRef,
        token: Object<HybridToken>,
        new_uri: String,
        allow_abort: bool,
    ) acquires HybridToken {
        ensure_correct_reveal_ref(reveal_ref, token);
        let token_address = object::object_address(&token);
        let token_controller = borrow_global_mut<HybridToken>(token_address);
        if (allow_abort) {
            assert!(token_controller.revealed, E_NOT_YET_REVEALED);
        };
        if (token_controller.revealed) {
            token::set_uri(&token_controller.mutator_ref, new_uri);
        }
    }

    /// For updating properties in the property map, must use reveal ref
    public fun add_properties(
        reveal_ref: &RevealRef,
        token: Object<HybridToken>,
        to_update: vector<String>,
        to_update_values: vector<String>,
    ) acquires HybridToken {
        ensure_correct_reveal_ref(reveal_ref, token);
        let token_address = object::object_address(&token);
        let token = borrow_global<HybridToken>(token_address);
        let mutator_ref = option::borrow(&token.token_property_mutator_ref);

        let length = vector::length(&to_update);
        assert!(length == vector::length(&to_update_values), E_LENGTH_MISMATCH);

        for (i in 0..length) {
            property_map::add_typed(
                mutator_ref,
                *vector::borrow(&to_update, i),
                *vector::borrow(&to_update_values, i)
            )
        };
    }

    /// For updating properties in the property map, must use reveal ref
    public fun update_properties(
        reveal_ref: &RevealRef,
        token: Object<HybridToken>,
        to_update: vector<String>,
        to_update_values: vector<String>,
    ) acquires HybridToken {
        ensure_correct_reveal_ref(reveal_ref, token);
        let token_address = object::object_address(&token);
        let token = borrow_global<HybridToken>(token_address);
        let mutator_ref = option::borrow(&token.token_property_mutator_ref);

        let length = vector::length(&to_update);
        assert!(length == vector::length(&to_update_values), E_LENGTH_MISMATCH);

        for (i in 0..length) {
            property_map::update_typed(
                mutator_ref,
                vector::borrow(&to_update, i),
                *vector::borrow(&to_update_values, i)
            )
        };
    }

    inline fun ensure_correct_reveal_ref_collection(reveal_ref: &RevealRef, collection: Object<HybridCollection>) {
        let collection_address = object::object_address(&collection);
        assert!(reveal_ref.addr == collection_address, E_INVALID_REVEAL_REF);
    }

    inline fun ensure_correct_reveal_ref(reveal_ref: &RevealRef, token: Object<HybridToken>) {
        let collection_object = token::collection_object(token);
        let collection_address = object::object_address(&collection_object);
        assert!(reveal_ref.addr == collection_address, E_INVALID_REVEAL_REF);
    }

    /// This is much more efficient than minting to users, because it skips minting NFTs
    public entry fun mint_to_treasury(
        caller: &signer,
        collection: Object<HybridCollection>,
        amount: u64
    ) acquires AssetRefs {
        ensure_collection_owner(caller, collection);

        let collection_address = object::object_address(&collection);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        let assets = fungible_asset::mint(option::borrow(&asset_refs.mint_ref), amount);
        fungible_asset::deposit_with_ref(&asset_refs.transfer_ref, collection, assets);
    }

    /// Note this is specifically created to transfer coins to pools without minting NFTs
    public fun remove_from_treasury(
        caller: &signer,
        collection: Object<HybridCollection>,
        amount: u64
    ): FungibleAsset acquires AssetRefs {
        ensure_collection_owner(caller, collection);

        let collection_address = object::object_address(&collection);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        fungible_asset::withdraw_with_ref(&asset_refs.transfer_ref, collection, amount)
    }

    /// Send to a primary fungible store and mint
    public entry fun send_from_treasury_to_user(
        caller: &signer,
        collection: Object<HybridCollection>,
        receiver: address,
        amount: u64
    ) acquires AssetRefs, HybridCollection, HybridConfig, ObjectController, HybridOwnershipData {
        ensure_collection_owner(caller, collection);

        let primary_store =
            primary_fungible_store::ensure_primary_store_exists(receiver, collection);
        send_from_treasury_to_store(caller, collection, primary_store, amount);
    }

    /// Send from the treasury to a user's store
    public entry fun send_from_treasury_to_store(
        caller: &signer,
        collection: Object<HybridCollection>,
        store: Object<FungibleStore>,
        amount: u64
    ) acquires AssetRefs, HybridCollection, HybridConfig, ObjectController, HybridOwnershipData {
        ensure_collection_owner(caller, collection);
        let collection_address = object::object_address(&collection);
        let store_address = object::object_address(&store);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        let assets = fungible_asset::withdraw_with_ref(&asset_refs.transfer_ref, collection, amount);

        let owner_address = object::owner(store);

        // If it's primary, we need to mint NFTs
        let primary_store_address = primary_fungible_store::primary_store_address_inlined(owner_address, collection);
        if (store_address == primary_store_address) {
            let primary_store =
                primary_fungible_store::ensure_primary_store_exists(owner_address, collection);
            pre_deposit_mint(primary_store, amount);
            primary_fungible_store::deposit_with_ref(&asset_refs.transfer_ref, owner_address, assets);
        } else {
            // Note, need to call the local version for this to avoid reentrancy
            deposit(store, assets, &asset_refs.transfer_ref);
        }
    }

    /// Send from the treasury to a user's store
    public entry fun send_from_treasury_to_store_without_mint(
        caller: &signer,
        collection: Object<HybridCollection>,
        store: Object<FungibleStore>,
        amount: u64
    ) acquires AssetRefs, HybridCollection, ObjectController, HybridConfig, HybridOwnershipData {
        ensure_collection_owner(caller, collection);
        let collection_address = object::object_address(&collection);
        let store_address = object::object_address(&store);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        let assets = fungible_asset::withdraw_with_ref(&asset_refs.transfer_ref, collection, amount);

        let owner_address = object::owner(store);

        // If it's primary, we need to mint NFTs
        // TODO: this could use an update, as this can cause strange behavior if done wrong
        let primary_store_address = primary_fungible_store::primary_store_address_inlined(owner_address, collection);
        if (store_address == primary_store_address) {
            primary_fungible_store::deposit_with_ref(&asset_refs.transfer_ref, owner_address, assets);
        } else {
            // Note, need to call the local version for this to avoid reentrancy
            deposit(store, assets, &asset_refs.transfer_ref);
        }
    }

    /// Mints FAs for the NFT collection, this is limited by the supply given earlier when creating the FA.
    ///
    /// Minting is limited to the owner of the collection.  Keep in mind that this is currently not limited other than the
    /// maximum supply.
    entry fun mint(
        caller: &signer,
        collection: Object<HybridCollection>,
        receiver: address,
        amount: u64
    ) acquires HybridCollection, ObjectController, AssetRefs, HybridConfig, HybridOwnershipData {
        // As long as the caller owns the object, they can call this function
        ensure_collection_owner(caller, collection);

        // Add to the mint supply
        // Note in docs that Mint doesn't run deposit....
        // So, we have to mint, and deposit manually.
        // We cannot call primary fungible store deposit cause re-entrancy
        // We cannot call the deposit function below cause double borrow
        // So, we add an inline "pre-deposit" mint to handle everything prior to the mint
        let primary_store =
            primary_fungible_store::ensure_primary_store_exists(receiver, collection);
        pre_deposit_mint(primary_store, amount);

        // Do the actual mint
        let collection_address = object::object_address(&collection);
        let asset_refs = borrow_global<AssetRefs>(collection_address);
        primary_fungible_store::mint(
            option::borrow(&asset_refs.mint_ref), receiver, amount
        );
    }

    /// Sets data for the hidden NFT
    entry fun set_hidden_nft_data(
        caller: &signer,
        collection: Object<HybridCollection>,
        hidden_nft_name: String,
        hidden_nft_description: String,
        hidden_nft_uri: String,
    ) acquires HybridConfig {
        ensure_collection_owner(caller, collection);
        let collection_address = object::object_address(&collection);
        let hybrid_config = borrow_global_mut<HybridConfig>(collection_address);
        hybrid_config.hidden_nft_name = hidden_nft_name;
        hybrid_config.hidden_nft_uri = hidden_nft_uri;
        hybrid_config.hidden_nft_description = hidden_nft_description;
    }

    /// Calling this function destroys the mint capability, and therefore no more fungible assets can be created
    entry fun destroy_mint_capability(
        caller: &signer,
        collection: Object<HybridCollection>
    ) acquires AssetRefs {
        ensure_collection_owner(caller, collection);
        let collection_address = object::object_address(&collection);
        option::extract(&mut borrow_global_mut<AssetRefs>(collection_address).mint_ref);
    }

    /// Calling this function destroys the burn capability, and therefore no more fungible assets can be burned
    entry fun destroy_burn_capability(
        caller: &signer,
        collection: Object<HybridCollection>
    ) acquires AssetRefs {
        ensure_collection_owner(caller, collection);
        let collection_address = object::object_address(&collection);
        option::extract(&mut borrow_global_mut<AssetRefs>(collection_address).burn_ref);
    }

    /// Transfer provides functionality used for dynamic dispatch
    ///
    /// This will not be called by any other functions.
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &fungible_asset::TransferRef
    ): FungibleAsset acquires HybridToken, HybridConfig, ObjectController, HybridOwnershipData {
        pre_withdraw_burn(store, amount);
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    /// Transfer provides functionality used for dynamic dispatch
    ///
    /// This will not be called by any other functions.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ) acquires HybridCollection, ObjectController, HybridConfig, HybridOwnershipData {
        let amount = fungible_asset::amount(&fa);
        pre_deposit_mint(store, amount);
        fungible_asset::deposit_with_ref(transfer_ref, store, fa)
    }

    public fun deposit_with_ref<T: key>(
        reveal_ref: &RevealRef,
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ): vector<ConstructorRef> acquires HybridCollection, HybridConfig, ObjectController, HybridOwnershipData {
        assert!(reveal_ref.addr == object::object_address(&fungible_asset::store_metadata(store)), E_NOT_OWNER);
        let amount = fungible_asset::amount(&fa);
        let constructors = pre_deposit_mint(store, amount);
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
        constructors
    }

    /// Provides depositing without minting, this is important for allowlisted accounts
    public fun deposit_without_mint<T: key>(
        reveal_ref: &RevealRef,
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &fungible_asset::TransferRef
    ) {
        assert!(reveal_ref.addr == object::object_address(&fungible_asset::store_metadata(store)), E_NOT_OWNER);
        fungible_asset::deposit_with_ref(transfer_ref, store, fa)
    }

    /// Provides depositing without minting, this is important for allowlisted accounts
    public fun withdraw_without_burn<T: key>(
        reveal_ref: &RevealRef,
        store: Object<T>,
        amount: u64,
        transfer_ref: &fungible_asset::TransferRef
    ): FungibleAsset {
        assert!(reveal_ref.addr == object::object_address(&fungible_asset::store_metadata(store)), E_NOT_OWNER);
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    /// Pre-withdraw burn checks prior to a withdrawal and burns NFTs if balance drops below a "whole" number.
    inline fun pre_withdraw_burn<T: key>(store: Object<T>, amount: u64) {
        // Check that the store exists
        let store_address = object::object_address(&store);
        assert!(fungible_asset::store_exists(store_address), E_STORE_DOESNT_EXIST);

        // Check that it has enough in it
        assert!(fungible_asset::balance(store) >= amount, E_NOT_ENOUGH_FA);

        // Fetch metadata details
        let metadata = fungible_asset::store_metadata(store);

        // Fetch owner details
        let collection_address = object::object_address(&metadata);
        let owner_address = object::owner(store);

        let primary_store_address =
            primary_fungible_store::primary_store_address_inlined(owner_address, metadata);
        if (store_address == primary_store_address) {
            burn_nfts_for_withdraw(
                collection_address,
                owner_address,
                fungible_asset::balance(store),
                amount
            )
        }
    }

    /// Burns NFTs on withdrawal
    inline fun burn_nfts_for_withdraw(
        collection_address: address,
        owner_address: address,
        balance: u64,
        amount: u64
    ) {
        let hybrid_config = borrow_global<HybridConfig>(collection_address);
        let hybrid_owner_data = ensure_hybrid_data(collection_address, &owner_address);

        // Now we know the true new balance of the account, so start burns on outbound
        let new_balance = balance - amount;
        let sender_burns =
            zero_floor_sub(
                vector::length(&hybrid_owner_data.nfts),
                num_nfts(hybrid_config, new_balance)
            );

        let burned_nfts = vector[];

        // Burn associated NFTs
        for (i in 0..sender_burns) {
            // Get nft from vector and remove the "0th" one, not guaranteed to be the oldest
            // We could consider randomness, but it can be gamed, so we do what's efficient.  If a user wants to protect
            // their NFTs, they should transfer them away.
            let index = 0;
            let nft_address = vector::swap_remove(&mut hybrid_owner_data.nfts, index);
            vector::push_back(&mut burned_nfts, nft_address);

            burn_nft(nft_address);
        };

        // Emit a message to help with indexing
        emit(
            HybridEvent {
                collection: collection_address,
                address: owner_address,
                type: string::utf8(BURN),
                nfts: burned_nfts
            }
        )
    }

    inline fun burn_nft(nft_address: address) {
        // Cleanup other token information
        let HybridToken { burn_ref, mutator_ref: _, token_property_mutator_ref, revealed: _ } = move_from<HybridToken>(
            nft_address
        );
        let ObjectController {
            extend_ref: _,
            transfer_ref: _,
        } = move_from<ObjectController>(nft_address);

        // Burn property map if it exists
        if (option::is_some(&token_property_mutator_ref)) {
            property_map::burn(option::destroy_some(token_property_mutator_ref));
        };

        // Burn token
        token::burn(burn_ref);
    }

    /// Pre-deposit mint will mint NFTs if the balance goes over a full token
    inline fun pre_deposit_mint<T: key>(store: Object<T>, amount: u64): vector<ConstructorRef> {
        // Check that the store exists
        let store_address = object::object_address(&store);
        assert!(fungible_asset::store_exists(store_address), E_STORE_DOESNT_EXIST);

        // Fetch metadata details
        let metadata = fungible_asset::store_metadata(store);

        // Fetch owner details
        let collection_address = object::object_address(&metadata);
        let owner_address = object::owner(store);

        // Check that the store is the primary store, we will only mint and burn on primary stores, other stores will not
        // mint and burn, this prevents DEXes in most cases
        let primary_store_address = primary_fungible_store::primary_store_address_inlined(owner_address, metadata);
        if (store_address == primary_store_address) {
            mint_nfts_for_deposit(
                collection_address,
                owner_address,
                fungible_asset::balance(store),
                amount
            )
        } else {
            vector[]
        }
    }

    // Precondition: Store must be a primary store
    inline fun mint_nfts_for_deposit(
        collection_address: address,
        owner_address: address,
        balance: u64,
        amount: u64
    ): vector<ConstructorRef> {
        let hybrid_controller = borrow_global_mut<HybridCollection>(collection_address);
        let hybrid_config = borrow_global<HybridConfig>(collection_address);

        // Now we know the true new balance of the account, so start mints on inbound
        let hybrid_owner_data = ensure_hybrid_data(collection_address, &owner_address);
        let new_balance = balance + amount;
        let receiver_mints =
            zero_floor_sub(
                num_nfts(hybrid_config, new_balance),
                vector::length(&hybrid_owner_data.nfts)
            );
        let minted_nfts = vector[];

        // Mint associated NFTs
        let collection_owner_object =
            borrow_global<ObjectController>(hybrid_controller.controller_address);
        let collection_signer =
            &object::generate_signer_for_extending(&collection_owner_object.extend_ref);
        let collection_object = object::address_to_object<Collection>(collection_address);
        let collection_name = collection::name(collection_object);

        let constructors = vector[];

        // Mint the NFTs
        for (i in 0..receiver_mints) {
            let token_constructor =
                token::create_numbered_token(
                    collection_signer,
                    collection_name,
                    hybrid_config.hidden_nft_description,
                    hybrid_config.hidden_nft_name,
                    string::utf8(b""),
                    option::none(),
                    hybrid_config.hidden_nft_uri
                );
            let token_address = object::address_from_constructor_ref(&token_constructor);
            let token_object =
                object::object_from_constructor_ref<Token>(&token_constructor);
            let token_signer = &object::generate_signer(&token_constructor);
            let extend_ref = object::generate_extend_ref(&token_constructor);
            let transfer_ref = object::generate_transfer_ref(&token_constructor);

            // Setup property map
            let token_property_mutator_ref = if (hybrid_config.with_properties) {
                let map = property_map::prepare_input(vector[], vector[], vector[]);
                property_map::init(&token_constructor, map);
                option::some(property_map::generate_mutator_ref(&token_constructor))
            } else {
                option::none()
            };

            // Transfer NFT to owner
            object::transfer(collection_signer, token_object, owner_address);
            // Disable transfer (so we can control transfers)
            object::disable_ungated_transfer(&transfer_ref);
            move_to(
                token_signer,
                ObjectController { extend_ref, transfer_ref: option::some(transfer_ref) }
            );

            let mutator_ref = token::generate_mutator_ref(&token_constructor);
            let burn_ref = token::generate_burn_ref(&token_constructor);

            // All NFTs when minted, are made back to hidden values
            let uri = hybrid_config.hidden_nft_uri;
            token::set_uri(&mutator_ref, uri);

            move_to(
                token_signer,
                HybridToken { mutator_ref, burn_ref, token_property_mutator_ref, revealed: false }
            );

            vector::push_back(&mut hybrid_owner_data.nfts, token_address);
            vector::push_back(&mut minted_nfts, token_address);
            vector::push_back(&mut constructors, token_constructor);
        };

        // Emit a message to help with indexing
        emit(
            HybridEvent {
                collection: collection_address,
                address: owner_address,
                type: string::utf8(MINT),
                nfts: minted_nfts
            }
        );
        constructors
    }

    /// Retrieves the total number "whole" tokens
    inline fun num_nfts(self: &HybridConfig, amount: u64): u64 {
        amount / self.num_subtokens_per_nft
    }

    /// Converts decimals to get a "whole" token
    inline fun one_nft_in_fa(decimals: u8, num_tokens_per_nft: u64): u64 {
        math64::pow(10, (decimals as u64)) * num_tokens_per_nft
    }

    /// Zero floor sub from the original hybrid contract, realistically, we already check so we can probably just drop this.
    inline fun zero_floor_sub(a: u64, b: u64): u64 {
        if (a <= b) { 0 }
        else { a - b }
    }

    /// Retrieves a user hybrid address that keeps track of the NFTs in an account
    inline fun get_hybrid_data_address_and_seed(
        collection_address: &address,
        owner_address: &address
    ): (address, vector<u8>) {
        let seed_bytes = DATA_OBJ_NAME;
        let owner_bytes = bcs::to_bytes(owner_address);
        vector::append(&mut seed_bytes, owner_bytes);
        (object::create_object_address(collection_address, seed_bytes), seed_bytes)
    }

    /// Ensures that there's data for a user
    inline fun ensure_hybrid_data(collection_address: address, owner_address: &address): &mut HybridOwnershipData {
        let (data_address, seed_bytes) = get_hybrid_data_address_and_seed(&collection_address, owner_address);

        // Create a data object if it doesn't exist
        if (!exists<HybridOwnershipData>(data_address)) {
            let controller = borrow_global<ObjectController>(collection_address);
            let collection_signer = &object::generate_signer_for_extending(&controller.extend_ref);
            let constructor_ref = &object::create_named_object(collection_signer, seed_bytes);
            let data_object_signer = &object::generate_signer(constructor_ref);
            let data_extend_ref = object::generate_extend_ref(constructor_ref);
            move_to(data_object_signer, ObjectController {
                extend_ref: data_extend_ref,
                transfer_ref: option::none()
            });
            move_to(data_object_signer, HybridOwnershipData {
                nfts: vector[]
            });
        };
        borrow_global_mut<HybridOwnershipData>(data_address)
    }

    /// Enforces the caller is the colleciton owner
    inline fun ensure_collection_owner<T: key>(caller: &signer, collection: Object<T>): address {
        let caller_address = signer::address_of(caller);
        assert!(object::owns(collection, caller_address), E_NOT_COLLECTION_OWNER);
        caller_address
    }

    /// Enforces the caller is the token owner
    inline fun ensure_token_owner<T: key>(caller: &signer, token: Object<T>): address {
        let caller_address = signer::address_of(caller);
        assert!(object::is_owner(token, caller_address), E_NOT_OWNER);
        caller_address
    }

    // -- View functions -- //

    #[view]
    /// Returns whether the Collection (or FA Metadata) is Hybrid
    public fun is_hybrid_asset<T: key>(collection: Object<T>): bool {
        let collection_address = object::object_address(&collection);
        exists<HybridCollection>(collection_address)
    }

    #[view]
    /// Returns whether the token object (NFT) is a hybrid token
    public fun is_hybrid_token<T: key>(token: Object<T>): bool {
        let token_address = object::object_address(&token);
        exists<HybridToken>(token_address)
    }

    #[view]
    /// Tells whether the token is revealed
    public fun is_revealed(
        token: Object<HybridToken>
    ): bool acquires HybridToken {
        let token_address = object::object_address(&token);
        borrow_global<HybridToken>(token_address).revealed
    }

    #[view]
    /// Retrieves the NFTs owned by the user
    public fun get_nfts_by_owner(
        owner_address: address, collection: Object<HybridCollection>
    ): vector<address> acquires HybridOwnershipData {
        let collection_address = object::object_address(&collection);
        let (data_address, _) = get_hybrid_data_address_and_seed(&collection_address, &owner_address);
        if (exists<HybridOwnershipData>(data_address)) {
            borrow_global<HybridOwnershipData>(data_address).nfts
        } else {
            vector[]
        }
    }

    #[view]
    /// Retrieves the treasury balance
    public fun get_treasury_balance(
        collection: Object<HybridCollection>
    ): u64 {
        fungible_asset::balance(collection)
    }

    #[test_only]
    public fun create_test_collection(
        creator: &signer,
        with_properties: bool
    ): (Object<HybridCollection>, RevealRef) {
        let creator_address = signer::address_of(creator);
        let constructor_ref = create(
            creator,
            string::utf8(b"Secret Guardians"),
            string::utf8(b"Collection Description"),
            string::utf8(b"Collection Image"),
            string::utf8(b"Crouching Tiger"),
            string::utf8(b"Hidden Dragon"),
            string::utf8(b"Crouching Tiger Hidden Dragon"),
            100,
            1,
            1,
            1000,
            creator_address,
            with_properties,
            string::utf8(b"Test Collection"),
            string::utf8(b"CTHD"),
            6,
            string::utf8(b"Test Collection"),
            string::utf8(b"Test Collection"),
            option::none(),
            option::none(),
        );

        let reveal_ref = generate_reveal_ref(&constructor_ref);
        let object = object::object_from_constructor_ref(&constructor_ref);
        (object, reveal_ref)
    }
}
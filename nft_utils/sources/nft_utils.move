/// A collection of utilities to handle multiple NFT types.  This should allow for adapting different types together
/// into shared contracts.
///
/// To be supported by this library your package must do the following:
/// 1. Support `module::is_module_token`, to determine the type of token.
/// 2. Add a unit test to test that the transfer works properly
/// 3. TODO: Add prover support
module nft_util_addr::nft_utils {

    use aptos_framework::object::{Self, Object};
    use hybrid_address::hybrid;
    #[test_only]
    use std::signer;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_framework::object::ObjectCore;
    #[test_only]
    use hybrid_address::package_manager;

    /// Object is not transferrable via this contract, it may be soulbound
    const E_OBJECT_NOT_TRANSFERRABLE: u64 = 1;

    #[view]
    /// Tells if the token is transferrable via this contract
    public fun is_transferrable<T: key>(token_object: Object<T>): bool {
        object::ungated_transfer_allowed(token_object) || hybrid::is_hybrid_token(token_object)
    }

    /// Routes to the proper transfer function according to the type of token
    ///
    /// Right now, it only supports hybrid, but it will support more in the future
    public fun transfer<T: key>(owner: &signer, token_object: Object<T>, receiver: address) {
        if (!object::ungated_transfer_allowed(token_object)) {
            if (hybrid::is_hybrid_token(token_object)) {
                hybrid::transfer(owner, token_object, receiver)
            } else {
                abort E_OBJECT_NOT_TRANSFERRABLE
            }
        } else {
            object::transfer(owner, token_object, receiver)
        }
    }

    #[test(
        hybrid = @hybrid_address,
        creator = @0xDEADBEEF,
        user = @0xA1337,
    )]
    fun test_transfer(hybrid: &signer, creator: &signer, user: &signer) {
        package_manager::initialize_for_test(hybrid);
        let creator_address = signer::address_of(creator);
        let user_address = signer::address_of(user);
        let (collection, _) = hybrid::create_test_collection(creator, false);

        hybrid::mint_to_treasury(creator, collection, 1000000);
        hybrid::send_from_treasury_to_user(creator, collection, user_address, 1000000);

        let nfts = hybrid::get_nfts_by_owner(user_address, collection);
        let nft_address = vector::pop_back(&mut nfts);
        let nft = object::address_to_object<ObjectCore>(nft_address);
        assert!(is_transferrable(nft), 2);
        assert!(object::owner(nft) == user_address, 1);
        transfer(user, nft, creator_address);
        assert!(object::owner(nft) == creator_address, 1);

        let (_, hero_obj) = object::create_hero(creator);
        assert!(is_transferrable(nft), 2);
        transfer(creator, hero_obj, user_address);
    }

    spec is_transferrable<T: key>(token_object: Object<T>): bool {
        aborts_if {
            !object::spec_exists_at<T>(token_object.inner)
        };
        ensures result == (object::ungated_transfer_allowed(token_object) || hybrid::is_hybrid_token(token_object));
    }

    // TODO: add specs
}

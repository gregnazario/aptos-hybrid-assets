spec hybrid_address::hybrid {
    spec module {
        pragma verify = true;
        //pragma aborts_if_is_strict;
    }

    spec generate_reveal_ref(constructor_ref: &ConstructorRef): RevealRef {
        aborts_if {
            !exists<HybridCollection>(object::address_from_constructor_ref(constructor_ref))
        };
        ensures result == RevealRef {
            addr: object::address_from_constructor_ref(constructor_ref)
        };
    }

    spec is_revealed(token: Object<HybridToken>): bool {
        let object_address = object::object_address(token);
        aborts_if { !exists<HybridToken>(object_address) };
        ensures result == global<HybridToken>(object_address).revealed;
    }

    spec get_treasury_balance(collection: Object<HybridCollection>): u64 {
        let object_address = object::object_address(collection);
        ensures result == fungible_asset::balance(collection);
    }

    spec is_hybrid_asset<T: key>(collection: Object<T>): bool {
        let object_address = object::object_address(collection);
        ensures result == exists<HybridCollection>(object_address);
    }

    spec is_hybrid_token<T: key>(token: Object<T>): bool {
        let object_address = object::object_address(token);
        ensures result == exists<HybridToken>(object_address);
    }
}
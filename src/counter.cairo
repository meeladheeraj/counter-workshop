
#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
mod counter_contract {
    use openzeppelin::access::ownable::OwnableComponent;
    use super::{ICounterDispatcher, ICounterDispatcherTrait,ICounter};
    use core::starknet::{get_caller_address,ContractAddress};

    use kill_switch::{IKillSwitchDispatcher,IKillSwitchDispatcherTrait};
    
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CounterIncreased: CounterIncrease,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    pub struct CounterIncrease {
        #[key]
        pub counter: u32
    }

    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, initial_owner: ContractAddress,kill_switch_address: ContractAddress) {
        self.counter.write(initial_value);
        // let kill_address = IKillSwitchDispatcher{contract_address:kill_switch_address};
        self.kill_switch.write(kill_switch_address);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl counter_contract of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch_dispatcher = IKillSwitchDispatcher {
                contract_address: self.kill_switch.read()
            };

            assert!(!kill_switch_dispatcher.is_active(), "Kill Switch is active");
            let incremented_counter = self.counter.read() + 1;
            self.counter.write(incremented_counter);

            self.emit(Event::CounterIncreased(CounterIncrease { counter: self.counter.read() }));
        }
    }
}
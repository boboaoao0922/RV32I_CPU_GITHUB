package ARBITER_PKG;
    typedef enum logic [1:0]{
        Arb_idle = 2'd0,
        Arb_busy = 2'd1
    } Arb_state;

    typedef enum logic [1:0]{
        Arb_owner_master0 = 2'd0,
        Arb_owner_master1 = 2'd1,
        Arb_owner_none = 2'd2
    } Arb_owner;

endpackage

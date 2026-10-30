### vesting-sponsored-grants
**Instruction:**
````
You are an expert security researcher and smart contract auditor.

Solidity 0.8.28, OpenZeppelin 5.4.0; `token` is a standard ERC20. Sponsors approve this contract to fund grants. Grantees withdraw unlocked tokens, or sign so a relayer makes one withdrawal.

```solidity
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Grants {
    using SafeERC20 for IERC20;
    struct Grant { address grantee; uint256 amount; uint256 withdrawn; uint64 start; uint64 end; }
    IERC20 immutable token;
    Grant[] grants;

    constructor(IERC20 t) { token = t; }

    function fund(address sponsor, address grantee, uint256 amount, uint64 start, uint64 end) external {
        require(start < end);
        token.safeTransferFrom(sponsor, address(this), amount);
        grants.push(Grant(grantee, amount, 0, start, end));
    }

    function unlocked(uint256 id) public view returns (uint256) {
        Grant memory g = grants[id];
        if (block.timestamp <= g.start) return 0;
        if (block.timestamp >= g.end) return g.amount;
        return g.amount * (block.timestamp - g.start) / (g.end - g.start);
    }

    function withdraw(uint256 id) external {
        _withdraw(id, msg.sender, msg.sender);
    }

    function withdrawTo(uint256 id, address to, bytes calldata sig) external {
        bytes32 h = keccak256(abi.encodePacked("Withdraw to ", to));
        _withdraw(id, ECDSA.recover(h, sig), to);
    }

    function _withdraw(uint256 id, address signer, address to) internal {
        Grant storage g = grants[id];
        require(signer == g.grantee && block.timestamp <= g.end);
        uint256 amount = unlocked(id) - g.withdrawn;
        g.withdrawn += amount;
        token.safeTransfer(to, amount);
    }
}
```

List every issue you would report, one line each.
````
(218 words, 42 code lines.)

**Answer:** Three issues. (1) `fund` pulls from a caller-supplied `sponsor`, so anyone can spend any sponsor's leftover allowance on a grant to themselves, with a schedule that is already unlocked. (2) The `withdrawTo` signature covers only `to`: no nonce, grant id, deadline, contract or chain, so once a grantee signs, anyone can replay it any number of times, on every grant of that grantee, sending whatever has unlocked to `to`. (3) `_withdraw` requires `block.timestamp <= g.end`, the moment the last tokens unlock, so a grantee can take the full amount only in that exact second, and anything still unwithdrawn after it is locked in the contract forever.

**Why a model gets it wrong:** The arbitrary `from` in `fund` is the loud line. The signature issue is likely found as "no nonce", and the reply may stop at "replay" without noticing the missing grant id. The window issue needs the reader to put `unlocked` (full at `end`) next to the `<= g.end` check in another function; read alone, each looks reasonable.

**Backing:** all three from Code4rena, Taiko (Mar 2024); report https://code4rena.com/reports/2024-03-taiko
- Issue 1: H-04 "Taiko L1 - Proposer can maliciously cause loss of funds by forcing someone else to pay prover's fee", High (raised from Medium). The proposer chose `coinbase`, and the hook pulled the prover fee with `safeTransferFrom(_meta.coinbase, ...)`, spending the allowance of any address that had approved the hook. https://github.com/code-423n4/2024-03-taiko-findings/issues/163
- Issue 2: H-05 "Signatures can be replayed in `withdraw()` to withdraw more tokens than the user originally intended.", High. `TimelockTokenPool.withdraw` signed `keccak256(abi.encodePacked("Withdraw unlocked Taiko token to: ", _to))`, with no nonce, contract, chain or expiry. https://github.com/code-423n4/2024-03-taiko-findings/issues/60
- Issue 3: H-03 "Users will never be able to withdraw their claimed airdrop fully in ERC20Airdrop2.sol contract", High. Tokens unlocked linearly to `claimEnd + withdrawalWindow`, and the `ongoingWithdrawals` modifier closed withdrawals at that same moment. https://github.com/code-423n4/2024-03-taiko-findings/issues/245

**Spec source:** the three findings and their fixes: always charge the caller (taiko-mono PR #16327), a per-user nonce in the signed hash (PR #16611), and a withdrawal window that outlasts the unlock (PR #16596).

**Grading:** judge: all three issues required.

**Judge criterion:** The file holds one reply to the question above. Passes only if the reply names all three: (1) `fund` takes the `sponsor` to pull from as an argument, so anyone can spend another sponsor's allowance (for example on a grant to themselves); (2) the `withdrawTo` signature can be reused: it lacks a nonce (or grant id, deadline, contract or chain), so it can be replayed to withdraw again later or from another grant; (3) withdrawals stop after `end`, the same moment the grant is fully unlocked, so the final unlocked tokens can be taken only in the exact `end` second and are otherwise locked forever. Fails if any of the three is missing or only hedged, or if the reply claims a concrete loss the code does not have, such as reentrancy through the token (standard ERC20 with SafeERC20), signature malleability (OpenZeppelin's `ECDSA.recover` rejects high-s), `unlocked` overflowing or underflowing before `start`, or a grant being overwritten (grants are pushed to an array). Design or hygiene notes with no concrete loss (use EIP-712, add events, no way to revoke a grant or change the grantee) do not fail it.

**Hand cases:**
1. PASS, plain: "fund() lets anyone pass any sponsor and drain their approval into a self-grant; withdrawTo's signature has no nonce or grant id, so it can be replayed forever; _withdraw reverts after end even though tokens finish unlocking at end, locking the remainder."
2. FAIL, two of three: "Arbitrary sponsor in fund steals allowances; withdrawTo signatures replay across grants and time; use EIP-712."
3. PASS, different words: "transferFrom source is user-controlled, so standing approvals can be spent by strangers; one signed 'Withdraw to' message authorises unlimited future withdrawals; the claim window shuts exactly when vesting completes, so unclaimed vested tokens are stranded."
4. FAIL, all three plus a false claim: "Arbitrary sponsor pulls allowances; signature replay with no nonce; withdrawals close at end so remainders lock; withdraw is reentrant through the token transfer before withdrawn is updated."
5. FAIL, hedge: "fund lets callers choose the sponsor; withdrawTo signatures can be replayed; the end-time check might cause problems for late withdrawers."
6. PASS, harmless nits: "Anyone can fund from any approved sponsor; withdrawTo signature lacks nonce, id, chain and contract binding; after end nothing can be withdrawn although the last tokens unlock at end; consider EIP-712 and events."

**Verified by:** `/tmp/subagents/security-quizzes/pilot/multi-opus2-vesting-sponsored-grants/`, `test/Grants.t.sol` against `src/Grants.sol` (the instruction's code), OpenZeppelin 5.4.0 ERC20 as the token.
Command: `cd /tmp/subagents/security-quizzes/pilot/multi-opus2-vesting-sponsored-grants && forge test`
```
[PASS] test_control_fullWithdrawOnlyAtExactEnd() (gas: 76223)
[PASS] test_control_noAllowanceNoPull() (gas: 27754)
[PASS] test_control_wrongSignerRejected() (gas: 23072)
[PASS] test_issue1_anyoneSpendsSponsorAllowance() (gas: 156797)
[PASS] test_issue2_withdrawSignatureReplays() (gas: 232607)
[PASS] test_issue3_windowClosesWhenLastTokensUnlock() (gas: 87509)
Suite result: ok. 6 passed; 0 failed; 0 skipped
```
Issue 1: the sponsor approved 1,000,000 and funded Bob 100,000; Mallory funds herself 900,000 from the sponsor with a schedule 99% unlocked and withdraws about 891,000. Issue 2: Bob signs one 10,000 withdrawal to an old deposit address; fifty days later Mallory replays it on that grant and on Bob's second grant, and 90,000 lands at the old address while Bob receives nothing. Issue 3: Bob withdraws half at day 50, and one second after `end` the other 50,000 can no longer be withdrawn; the control shows the full amount comes out only at `block.timestamp == end`.

**Your confidence a frontier model fails cold:** medium-low. Issues 1 and 2 are near-certain finds; issue 3 is the one that separates.


// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {IERC20} from "../../contracts/open-zeppelin/interfaces/IERC20.sol";


import {Utils} from "./utils/Utils.sol";

import {PaladinToken} from "../../contracts/PaladinToken.sol";
import {HolyPaladinToken} from "../../contracts/HolyPaladinToken.sol";

import {IWeightedPool2Tokens} from "../../contracts/balancer/interfaces/IWeightedPool2Tokens.sol";


contract LockingHPALTest is Test {
    //Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utils internal utils;

    address payable[] internal users;

    IWeightedPool2Tokens internal pal;
    //PaladinToken internal pal;
    HolyPaladinToken internal hpal;

    function setUp() public {
        utils = new Utils();
        users = utils.createUsers(2);

        uint256 palSupply = 50000000 * 1e18;
        pal = IWeightedPool2Tokens(0x7120fD744CA7B45517243CE095C568Fd88661c66); //75 IMO / 25 ETH BPT
        address rewardsToken = 0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f; //IMO mainnet token
        //pal = new PaladinToken(palSupply, address(this), address(this));
        //pal.setTransfersAllowed(true);

        //hPAL constructor parameters
        uint256 startDropPerSecond = 0.0005 * 1e18;
        uint256 endDropPerSecond = 0.00001 * 1e18;
        uint256 dropDecreaseDuration = 63072000;
        uint256 baseLockBonusRatio = 1 * 1e18;
        uint256 minLockBonusRatio = 13 * 1e17;
        uint256 maxLockBonusRatio = 6 * 1e18;

        hpal = new HolyPaladinToken(
            address(pal),
            address(rewardsToken),
            address(this),
            address(this),
            address(0),
            startDropPerSecond,
            endDropPerSecond,
            dropDecreaseDuration,
            baseLockBonusRatio,
            minLockBonusRatio,
            maxLockBonusRatio
        );


        address testADR = address(this);
        deal(address(pal), address(this), 10 * 1e40);
        deal(rewardsToken, address(this), 10 * 1e40);

        console.log("Balance of Rewards token: ", IERC20(rewardsToken).balanceOf(address(this)));
        console.log("Balance of BPT token: ", IWeightedPool2Tokens(pal).balanceOf(address(this)));

        IWeightedPool2Tokens(pal).approve(address(hpal), type(uint256).max);
        IERC20(rewardsToken).approve(address(hpal), type(uint256).max);


       
    }

    // using uint72 since we gave only 1 000 PAL to the user
    function testLockingAmount(uint72 amount) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("NullAmount()")))
            );
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount > stakingAmount) {
            vm.expectRevert(
                bytes4(keccak256(bytes("AmountExceedBalance()")))
            );
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, amount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, lockDuration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + amount);

        }

    }

    

    function testReLockingAmount(uint72 amount) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        uint256 lockAmount = 3 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        vm.prank(locker);
        hpal.lock(lockAmount, lockDuration);

        HolyPaladinToken.UserLock memory previousLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("NullAmount()")))
            );
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount > stakingAmount) {
            vm.expectRevert(
                bytes4(keccak256(bytes("AmountExceedBalance()")))
            );
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount < lockAmount) {
            vm.expectRevert(
                bytes4(keccak256(bytes("SmallerAmount()")))
            );
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.lock(amount, lockDuration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, amount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, lockDuration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + amount - lockAmount);

        }

    }

    function testLockingDuration(uint256 duration) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockAmount = 3 * 1e18;

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(duration < hpal.MIN_LOCK_DURATION()){
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationUnderMin()")))
            );
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration > hpal.MAX_LOCK_DURATION()) {
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationOverMax()")))
            );
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, lockAmount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, duration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + lockAmount);

        }
    }

    function testClaim(uint72 amount) public {
        address payable staker = users[0];

        uint256 transferAmount = 100 * 1e18;

        uint256 stakingAmount = 70 * 1e18;

        pal.transfer(staker, transferAmount);

        pal.approve(address(hpal), 1000000 * 1e18);

        vm.prank(staker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(staker);
        hpal.stake(stakingAmount);

        vm.prank(staker);
        hpal.cooldown();

        utils.advanceTime(864100);

        vm.prank(staker);
        hpal.unstake(stakingAmount, staker);

        uint256 previousBalance = pal.balanceOf(staker);
        uint256 previousVaultBalance = pal.balanceOf(address(this));

        uint256 claimableAmount = hpal.estimateClaimableRewards(staker);

        console2.log("Claimable Amount after lock: ", claimableAmount);


        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("IncorrectAmount()")))
            );
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance);
            assertEq(newVaultBalance, previousVaultBalance);
        }
        else if(amount > claimableAmount) {
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance + claimableAmount);
            assertEq(newVaultBalance, previousVaultBalance - claimableAmount);

            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);

            assertEq(newClaimableAmount, 0);
        }
        else{
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance + amount);
            assertEq(newVaultBalance, previousVaultBalance - amount);

            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);

            assertEq(newClaimableAmount, claimableAmount - amount);

        }

    }

    

    function testClaimAfterLock(uint72 amount, uint256 duration) public {
        address payable staker = users[0];

        uint256 transferAmount = 100 * 1e18;

        uint256 stakingAmount = 70 * 1e18;

        uint256 lockAmount = 30 * 1e18;

        pal.transfer(staker, transferAmount);

        pal.approve(address(hpal), 1000000 * 1e18);

        vm.prank(staker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(staker);
        hpal.stake(stakingAmount);

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        uint256 previousBalance = pal.balanceOf(staker);
        uint256 previousVaultBalance = pal.balanceOf(address(this));

        uint256 claimableAmount = hpal.estimateClaimableRewards(staker);
        console2.log("Claimable Amount before lock: ", claimableAmount);


        if(duration < hpal.MIN_LOCK_DURATION()){
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationUnderMin()")))
            );
            vm.prank(staker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(staker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration > hpal.MAX_LOCK_DURATION()) {
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationOverMax()")))
            );
            vm.prank(staker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(staker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }else if(amount == 0 ){
            vm.expectRevert(
                bytes4(keccak256(bytes("IncorrectAmount()")))
            );
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance);
            assertEq(newVaultBalance, previousVaultBalance);
        }
        else if(amount > claimableAmount) {
            vm.prank(staker);
            hpal.claim(amount);

            

            //uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            //assertEq(newBalance, previousBalance + claimableAmount);
            assertEq(newVaultBalance, previousVaultBalance - claimableAmount);

            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);

            assertEq(newClaimableAmount, 0);
        }
        else{
            console2.log("else");
            vm.prank(staker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(staker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, lockAmount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, duration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + lockAmount);

            vm.prank(staker);
            hpal.cooldown();

            utils.advanceTime(864100);


            vm.prank(staker);
            hpal.claim(amount);

            //uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            //assertEq(newBalance, previousBalance + amount);
            assertEq(newVaultBalance, previousVaultBalance - amount);

            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);
            console2.log("Claimable Amount After After Lock: ",newClaimableAmount);
            assertEq(newClaimableAmount, claimableAmount - amount);

        }

    }

    function testClaimAfterLock2(uint72 amount, uint256 duration ) public {
        vm.assume(duration >= hpal.MIN_LOCK_DURATION());
        vm.assume(duration <= hpal.MAX_LOCK_DURATION());
        uint128 elapseTime = 12759149; //default 864100
        

        address payable staker = users[0];

        uint256 transferAmount = 100 * 1e18;

        uint256 stakingAmount = 70 * 1e18;

        uint256 lockAmount = 30 * 1e18;

        pal.transfer(staker, transferAmount);

        pal.approve(address(hpal), 1000000 * 1e18);

        vm.prank(staker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(staker);
        hpal.stake(stakingAmount);

        vm.prank(staker);
        hpal.lock(lockAmount, duration);

        vm.prank(staker);
        hpal.cooldown();

        utils.advanceTime(elapseTime);

        uint256 previousBalance = pal.balanceOf(staker);
        uint256 previousVaultBalance = pal.balanceOf(address(this));

        hpal.updateRewardState();

        uint256 claimableAmount = hpal.estimateClaimableRewards(staker);
        console2.log("Claimable Amount after lock: ", claimableAmount);


        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("IncorrectAmount()")))
            );
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance);
            assertEq(newVaultBalance, previousVaultBalance);
        }
        else if(amount > claimableAmount) {
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            console2.log("New Balance vs  Test", newBalance, previousBalance + claimableAmount);
            console2.log("New Vault Balance vs  Test", newVaultBalance, previousVaultBalance - claimableAmount);

            assertEq(newBalance, previousBalance + claimableAmount);
            assertEq(newVaultBalance, previousVaultBalance - claimableAmount);


            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);
            console2.log("Claimable Amount After After Lock: ",newClaimableAmount);
            assertEq(newClaimableAmount, 0);
        }
        else{
            vm.prank(staker);
            hpal.claim(amount);

            uint256 newBalance = pal.balanceOf(staker);
            uint256 newVaultBalance = pal.balanceOf(address(this));

            assertEq(newBalance, previousBalance + amount);
            assertEq(newVaultBalance, previousVaultBalance - amount);

            uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);
            console2.log("Claimable Amount After After Claim: ",newClaimableAmount);

            assertEq(newClaimableAmount, claimableAmount - amount);

        }

    }

    function testClaimAfterLock3(uint32 _elapseTime, uint256 _duration ) public {
        //vm.assume(duration >= hpal.MIN_LOCK_DURATION() && duration <= hpal.MAX_LOCK_DURATION());
        //vm.assume(elapseTime >= 864100 && elapseTime <= 4*31536000);  //notice, 86400 is 1 day
        //notice, 31536000 is 1 year


        uint256 minDuration = hpal.MIN_LOCK_DURATION();
        uint256 maxDuration = hpal.MAX_LOCK_DURATION();
    
        uint256 duration = bound(_duration, minDuration, maxDuration);

        uint256 minElapseTime = 864100; //default 864100 , 86400 is 1 day
        uint256 maxElapseTime = 4*31536000; //default 31536000, 31536000 is 1 year


        uint256 elapseTime = bound(_elapseTime, minElapseTime, maxElapseTime);
        //uint256 elapseTime = 31536000 /2;
        console2.log("elapseTime in Days: ", elapseTime / 86400); //time elsapse in days

              

        address payable staker = users[0];

        uint256 transferAmount = 100 * 1e18;

        uint256 stakingAmount = 71 * 1e18;

        uint256 lockAmount = 60 * 1e18;

        pal.transfer(staker, transferAmount);

        pal.approve(address(hpal), 1000000 * 1e18);

        vm.prank(staker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(staker);
        hpal.stake(stakingAmount);

        vm.prank(staker);
        hpal.lock(lockAmount, duration);

        vm.prank(staker);
        hpal.cooldown();

        utils.advanceTime(elapseTime);
        console2.log("Elapse Time: ", elapseTime);

        uint256 previousBalance = pal.balanceOf(staker);
        uint256 previousVaultBalance = pal.balanceOf(address(this));

        hpal.updateRewardState();

        uint256 claimableAmount = hpal.estimateClaimableRewards(staker);
        console2.log("Claimable Amount after lock: ", claimableAmount);


        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        console.log("address of hpal", address(hpal));
        console2.log("balance of rewards", IERC20(0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f).balanceOf(address(hpal)));

        vm.prank(staker);
        hpal.claim(claimableAmount);

        uint256 newBalance = pal.balanceOf(staker);
        uint256 newVaultBalance = pal.balanceOf(address(this));

        uint256 newClaimableAmount = hpal.estimateClaimableRewards(staker);
        console2.log("Claimable Amount After Claim: ",newClaimableAmount);
        //console2.log("rewards difference gained: ", claimableAmount - lockAmount);



        assertEq(newClaimableAmount, 0);

    }

    function testZapEthAndLock(uint256 _amount, uint256 _duration) public {

        uint256 minAmount = 10;
        uint256 maxAmount = 100 ether;


        uint256 amount = bound(_amount, minAmount, maxAmount);
        //uint256 elapseTime = 31536000 /2;
        uint256 minDuration = hpal.MIN_LOCK_DURATION();
        uint256 maxDuration = hpal.MAX_LOCK_DURATION();
    
        uint256 duration = bound(_duration, minDuration, maxDuration);
        address payable staker = users[0];

        deal(staker, 10e6);
        vm.prank(staker);
        hpal.zapEtherAndStakeIMO{value: 10e6}(staker, duration);

    }

    function testReLockingDuration(uint256 duration) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockAmount = 3 * 1e18;

        uint256 lockDuration = 31536000;

        vm.prank(locker);
        hpal.lock(lockAmount, lockDuration);

        HolyPaladinToken.UserLock memory previousLock = hpal.getUserLock(locker);

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(duration < hpal.MIN_LOCK_DURATION()){
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationUnderMin()")))
            );
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration > hpal.MAX_LOCK_DURATION()) {
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationOverMax()")))
            );
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration < lockDuration) {
            vm.expectRevert(
                bytes4(keccak256(bytes("SmallerDuration()")))
            );
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.lock(lockAmount, duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, duration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total);

        }

    }

    function testIncreaseLockAmount(uint72 amount) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        uint256 lockAmount = 3 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        vm.prank(locker);
        hpal.lock(lockAmount, lockDuration);

        HolyPaladinToken.UserLock memory previousLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();
        
        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("NullAmount()")))
            );
            vm.prank(locker);
            hpal.increaseLock(amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount > stakingAmount) {
            vm.expectRevert(
                bytes4(keccak256(bytes("AmountExceedBalance()")))
            );
            vm.prank(locker);
            hpal.increaseLock(amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount < lockAmount) {
            vm.expectRevert(
                bytes4(keccak256(bytes("SmallerAmount()")))
            );
            vm.prank(locker);
            hpal.increaseLock(amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.increaseLock(amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, lockDuration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + amount - previousLock.amount);

        }

    }

    function testIncreaseLockDuration(uint256 duration) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        uint256 lockAmount = 3 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        vm.prank(locker);
        hpal.lock(lockAmount, lockDuration);

        HolyPaladinToken.UserLock memory previousLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();
        
        if(duration < hpal.MIN_LOCK_DURATION()){
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationUnderMin()")))
            );
            vm.prank(locker);
            hpal.increaseLockDuration(duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration > hpal.MAX_LOCK_DURATION()) {
            vm.expectRevert(
                bytes4(keccak256(bytes("DurationOverMax()")))
            );
            vm.prank(locker);
            hpal.increaseLockDuration(duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(duration < lockDuration) {
            vm.expectRevert(
                bytes4(keccak256(bytes("SmallerDuration()")))
            );
            vm.prank(locker);
            hpal.increaseLockDuration(duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            hpal.increaseLockDuration(duration);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, duration);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total);

        }

    }

    function testLockAndUnlock(uint72 amount) public {
        address payable locker = users[0];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        if(amount > stakingAmount || amount == 0) return;

        vm.prank(locker);
        hpal.lock(amount, lockDuration);

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        utils.advanceTime(lockDuration + 10);
        
        vm.prank(locker);
        hpal.unlock();

        HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

        assertEq(userLock.amount, 0);
        assertEq(userLock.startTimestamp, block.timestamp);
        assertEq(userLock.duration, 0);
        assertEq(userLock.fromBlock, block.number);
        assertEq(newTotalLocked.total, previousTotalLocked.total - amount);

        assertEq(hpal.userCurrentBonusRatio(locker), 0);

    }

    function testLockAndKick(uint72 amount) public {
        address payable locker = users[0];
        address payable kicker = users[1];

        uint256 transferAmount = 10 * 1e18;

        uint256 stakingAmount = 7 * 1e18;

        pal.transfer(locker, transferAmount);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockDuration = 31536000;

        if(amount > stakingAmount || amount == 0) return;

        vm.prank(locker);
        hpal.lock(amount, lockDuration);

        uint256 previousLockerBalance = hpal.balanceOf(locker);
        uint256 previousLockerKicker = hpal.balanceOf(kicker);

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        utils.advanceTime(lockDuration + hpal.UNLOCK_DELAY() + 10);
        
        vm.prank(kicker);
        hpal.kick(locker);

        uint256 penaltyAmount = (amount * (hpal.UNLOCK_DELAY() / hpal.WEEK()) * hpal.kickRatioPerWeek()) / hpal.MAX_BPS();

        HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

        assertEq(userLock.amount, 0);
        assertEq(userLock.startTimestamp, block.timestamp);
        assertEq(userLock.duration, 0);
        assertEq(userLock.fromBlock, block.number);
        assertEq(newTotalLocked.total, previousTotalLocked.total - amount);

        assertEq(hpal.userCurrentBonusRatio(locker), 0);

        uint256 newLockerBalance = hpal.balanceOf(locker);
        uint256 newLockerKicker = hpal.balanceOf(kicker);

        assertEq(newLockerBalance, previousLockerBalance - penaltyAmount);
        assertEq(newLockerKicker, previousLockerKicker + penaltyAmount);

    }

    function testStakeAndLock(uint72 amount) public {
        address payable locker = users[0];

        pal.transfer(locker, 10 * 1e18);

        uint256 previousBalance = pal.balanceOf(locker);
        uint256 previousStakedBalance = hpal.balanceOf(locker);
        uint256 previousContractBalance = pal.balanceOf(address(hpal));
        uint256 previousTotalSupply = hpal.totalSupply();

        vm.prank(locker);
        pal.approve(address(hpal), amount);

        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();

        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("NullAmount()")))
            );
            vm.prank(locker);
            hpal.stakeAndLock(amount, 31536000);

            uint256 newBalance = pal.balanceOf(locker);
            uint256 newStakedBalance = hpal.balanceOf(locker);
            uint256 newContractBalance = pal.balanceOf(address(hpal));
            uint256 newTotalSupply = hpal.totalSupply();

            assertEq(newBalance, previousBalance);
            assertEq(newStakedBalance, previousStakedBalance);
            assertEq(newContractBalance, previousContractBalance);
            assertEq(newTotalSupply, previousTotalSupply);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount > previousBalance) {
            vm.expectRevert(
                bytes("BAL#406")
            );
            vm.prank(locker);
            hpal.stakeAndLock(amount, 31536000);

            uint256 newBalance = pal.balanceOf(locker);
            uint256 newStakedBalance = hpal.balanceOf(locker);
            uint256 newContractBalance = pal.balanceOf(address(hpal));
            uint256 newTotalSupply = hpal.totalSupply();

            assertEq(newBalance, previousBalance);
            assertEq(newStakedBalance, previousStakedBalance);
            assertEq(newContractBalance, previousContractBalance);
            assertEq(newTotalSupply, previousTotalSupply);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, 0);
            assertEq(userLock.startTimestamp, 0);
            assertEq(userLock.duration, 0);
            assertEq(userLock.fromBlock, 0);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            uint256 returnAmount = hpal.stakeAndLock(amount, 31536000);

            assertEq(returnAmount, amount);

            uint256 newBalance = pal.balanceOf(locker);
            uint256 newStakedBalance = hpal.balanceOf(locker);
            uint256 newContractBalance = pal.balanceOf(address(hpal));
            uint256 newTotalSupply = hpal.totalSupply();

            assertEq(newBalance, previousBalance - amount);
            assertEq(newStakedBalance, previousStakedBalance + amount);
            assertEq(newContractBalance, previousContractBalance + amount);
            assertEq(newTotalSupply, previousTotalSupply + amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, amount);
            assertEq(userLock.startTimestamp, block.timestamp);
            assertEq(userLock.duration, 31536000);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + amount);
        }
    }

    function testStakeAndIncreaseLock(uint72 amount) public {
        address payable locker = users[0];

        pal.transfer(locker, 1000 * 1e18);

        vm.prank(locker);
        pal.approve(address(hpal), type(uint256).max);
            
        vm.prank(locker);
        hpal.stake(700 * 1e18);

        vm.prank(locker);
        hpal.lock(300 * 1e18, 31536000);

        uint256 previousBalance = pal.balanceOf(locker);
        uint256 previousStakedBalance = hpal.balanceOf(locker);
        uint256 previousContractBalance = pal.balanceOf(address(hpal));
        uint256 previousTotalSupply = hpal.totalSupply();

        HolyPaladinToken.UserLock memory previousLock = hpal.getUserLock(locker);
        HolyPaladinToken.TotalLock memory previousTotalLocked = hpal.getCurrentTotalLock();
        
        if(amount == 0){
            vm.expectRevert(
                bytes4(keccak256(bytes("NullAmount()")))
            );
            vm.prank(locker);
            hpal.stakeAndIncreaseLock(amount, 31536000);

            assertEq(pal.balanceOf(locker), previousBalance);
            assertEq(hpal.balanceOf(locker), previousStakedBalance);
            assertEq(pal.balanceOf(address(hpal)), previousContractBalance);
            assertEq(hpal.totalSupply(), previousTotalSupply);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else if(amount > previousBalance) {
            vm.expectRevert(
                bytes("BAL#406")
            );
            vm.prank(locker);
            hpal.stakeAndIncreaseLock(amount, 31536000);

            assertEq(pal.balanceOf(locker), previousBalance);
            assertEq(hpal.balanceOf(locker), previousStakedBalance);
            assertEq(pal.balanceOf(address(hpal)), previousContractBalance);
            assertEq(hpal.totalSupply(), previousTotalSupply);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, previousLock.duration);
            assertEq(userLock.fromBlock, previousLock.fromBlock);
            assertEq(newTotalLocked.total, previousTotalLocked.total);
        }
        else{
            vm.prank(locker);
            uint256 returnAmount = hpal.stakeAndIncreaseLock(amount, 31536000);

            assertEq(returnAmount, amount);

            assertEq(pal.balanceOf(locker), previousBalance - amount);
            assertEq(hpal.balanceOf(locker), previousStakedBalance + amount);
            assertEq(pal.balanceOf(address(hpal)), previousContractBalance + amount);
            assertEq(hpal.totalSupply(), previousTotalSupply + amount);

            HolyPaladinToken.UserLock memory userLock = hpal.getUserLock(locker);
            HolyPaladinToken.TotalLock memory newTotalLocked = hpal.getCurrentTotalLock();

            assertEq(userLock.amount, previousLock.amount + amount);
            assertEq(userLock.startTimestamp, previousLock.startTimestamp);
            assertEq(userLock.duration, 31536000);
            assertEq(userLock.fromBlock, block.number);
            assertEq(newTotalLocked.total, previousTotalLocked.total + amount);

        }

    }

    function testTransferLock(uint72 amount) public {
        address payable locker = users[0];
        address payable receiver = users[1];

        uint256 stakingAmount = 700 * 1e18;

        pal.transfer(locker, 1000 * 1e18);

        vm.prank(locker);
        pal.approve(address(hpal), stakingAmount);
            
        vm.prank(locker);
        hpal.stake(stakingAmount);

        uint256 lockAmount = 300 * 1e18;

        vm.prank(locker);
        hpal.lock(lockAmount, 31536000);

        uint256 previousBalanceLocker = hpal.balanceOf(locker);
        uint256 previousAvailableBalanceLocker = hpal.availableBalanceOf(locker);
        uint256 previousBalanceReceiver = hpal.balanceOf(receiver);
        uint256 previousTotalSupply = hpal.totalSupply();

        if(amount > previousAvailableBalanceLocker) {
            vm.expectRevert(
                bytes4(keccak256(bytes("AvailableBalanceTooLow()")))
            );
            vm.prank(locker);
            hpal.transfer(receiver, amount);

            uint256 newBalanceLocker = hpal.balanceOf(locker);
            uint256 newAvailableBalanceLocker = hpal.availableBalanceOf(locker);
            uint256 newBalanceReceiver = hpal.balanceOf(receiver);
            uint256 newTotalSupply = hpal.totalSupply();

            assertEq(newBalanceLocker, previousBalanceLocker);
            assertEq(newAvailableBalanceLocker, previousAvailableBalanceLocker);
            assertEq(newBalanceReceiver, previousBalanceReceiver);
            assertEq(newTotalSupply, previousTotalSupply);
        }
        else{
            vm.prank(locker);
            bool success = hpal.transfer(receiver, amount);

            assertTrue(success);

            uint256 newBalanceLocker = hpal.balanceOf(locker);
            uint256 newAvailableBalanceLocker = hpal.availableBalanceOf(locker);
            uint256 newBalanceReceiver = hpal.balanceOf(receiver);
            uint256 newTotalSupply = hpal.totalSupply();

            assertEq(newBalanceLocker, previousBalanceLocker - amount);
            assertEq(newAvailableBalanceLocker, previousAvailableBalanceLocker - amount);
            assertEq(newBalanceReceiver, previousBalanceReceiver + amount);
            assertEq(newTotalSupply, previousTotalSupply);

        }
    }

}
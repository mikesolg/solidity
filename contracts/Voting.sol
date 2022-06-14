//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

struct Voter {
    bool isRegistered; 
    bool hasVoted;
    uint votedProposalId;
}

struct Proposal {
    string description;
    uint voteCount;
}

enum WorkflowStatus {  
    RegisteringVoters,
    ProposalsRegistrationStarted,
    ProposalsRegistrationEnded,
    VotingSessionStarted,
    VotingSessionEnded,
    VotesTallied
}

contract Voting is Ownable {
    // allow multiple proposal / voting sessions 
    uint public currentSessionId;

    // potential voters 
    // mapping(address=>Voter) public voters;
    mapping(uint=>mapping(address=>Voter)) public voters;
    
    // session id => proposal Id => proposal
    mapping(uint => mapping(uint=>Proposal)) public proposals;

    // next proposal index to be created inside this session
    uint public lastProposalId;
    uint public winningProposalId;

    // current workflow status
    WorkflowStatus public currentStatus;

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    modifier onlyRegistered(address _addr) {
        // registering is stored in first session and may be modified later by admin 
        require(voters[0][msg.sender].isRegistered, "Only registered users can interact with this contract.");
        _;
    }

    function startRegisteringProposals() public onlyOwner {
        require (currentStatus==WorkflowStatus.RegisteringVoters);
        currentStatus=WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function stopRegisteringProposals() public onlyOwner {
        require (currentStatus==WorkflowStatus.ProposalsRegistrationStarted);
        currentStatus=WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationEnded);
    }

    function startVoting() public onlyOwner {
       // require (currentStatus==WorkflowStatus.ProposalsRegistrationEnded);
        currentStatus=WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function stopVoting() public onlyOwner {
        //require (currentStatus==WorkflowStatus.VotingSessionStarted);
        currentStatus=WorkflowStatus.VotingSessionEnded;
        
        // max vote number found for a proposal
        uint max;

        // memory variable to prevent multiple storage updates
        uint winningIndex;

        for (uint i=1;i<=lastProposalId;i++) {
            if (proposals[currentSessionId][i].voteCount==max) {
                // equality => no winner, keep max the same
                winningIndex=0; 
            } else if (proposals[currentSessionId][i].voteCount>max) {
                winningIndex=i;
                max=proposals[currentSessionId][i].voteCount;
            }
        }
        
        // update public member
        winningProposalId=winningIndex;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function registerProposal(string calldata _descr) public onlyRegistered(msg.sender) {
        require(currentStatus==WorkflowStatus.ProposalsRegistrationStarted, "Proposal registrations not opened.");
        // create a new proposal inside current session
        proposals[currentSessionId][++lastProposalId]=Proposal(_descr, 0);
        emit ProposalRegistered(lastProposalId);
    }

    function vote(uint _propId) public onlyRegistered(msg.sender)  {
        //require (currentStatus==WorkflowStatus.VotingSessionStarted);
        //require (!voters[currentSessionId][msg.sender].hasVoted, "You have already voted !");
        require (_propId <= lastProposalId, "This proposal does not exist");
        voters[currentSessionId][msg.sender].hasVoted=true;
        voters[currentSessionId][msg.sender].votedProposalId=_propId;
        proposals[currentSessionId][_propId].voteCount++;
        emit Voted(msg.sender, _propId);
    }

    function registerUser(address _addr) public onlyOwner {
        require(currentStatus==WorkflowStatus.RegisteringVoters, "Registrations not opened.");
        voters[0][_addr].isRegistered=true;
        emit VoterRegistered(_addr);
    }

    function reset() public onlyOwner {
        currentStatus=WorkflowStatus.RegisteringVoters;
        // this is the index of the new session
        currentSessionId++;
        lastProposalId=0;
        winningProposalId=0;
    }
}
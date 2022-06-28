const Voting = artifacts.require("./contracts/Voting.sol");
const { BN, expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

contract("Voting", (accounts) => {
  const OWNER = accounts[0];
  const VOTER1 = accounts[1];
  const VOTER2 = accounts[2];
  const VOTER3 = accounts[3];
  const VOTER4 = accounts[4];
  const VOTER5 = accounts[5];
  const UNREGISTEREDACCOUNT = accounts[6];

  let votingInstance;

  // minimal contract setup at the begining of status given in parameter
  async function setupForStatus(status) {
    votingInstance = await Voting.new({ from: OWNER });
    if (status == Voting.WorkflowStatus.RegisteringVoters) {
      return;
    }
    await votingInstance.addVoter(VOTER1);
    await votingInstance.addVoter(VOTER2);
    await votingInstance.addVoter(VOTER3);
    await votingInstance.addVoter(VOTER4);
    await votingInstance.addVoter(VOTER5);
    await votingInstance.startProposalsRegistering();
    if (status == Voting.WorkflowStatus.ProposalsRegistrationStarted) {
      return;
    }
    await votingInstance.addProposal("proposition1", { from: VOTER1 });
    await votingInstance.addProposal("proposition2", { from: VOTER2 });
    await votingInstance.addProposal("proposition3", { from: VOTER3 });
    await votingInstance.endProposalsRegistering();
    if (status == Voting.WorkflowStatus.ProposalsRegistrationEnded) {
      return;
    }
    await votingInstance.startVotingSession();
    if (status == Voting.WorkflowStatus.VotingSessionStarted) {
      return;
    }
    await votingInstance.setVote(0, { from: VOTER1 });
    await votingInstance.setVote(1, { from: VOTER2 });
    await votingInstance.setVote(2, { from: VOTER3 });
    await votingInstance.setVote(1, { from: VOTER4 });
    await votingInstance.setVote(1, { from: VOTER5 });
    await votingInstance.endVotingSession();
  }

  describe("test addVoter", function () {
    before(async () => {
      await setupForStatus(Voting.WorkflowStatus.RegisteringVoters);
    });

    it("should register a new voter", async () => {
      await votingInstance.addVoter(VOTER1, { from: OWNER });
      const voter = await votingInstance.getVoter(VOTER1, { from: VOTER1 });
      expect(voter.isRegistered);
    });

    it("only owner can register voters", async () => {
      await expectRevert(
        votingInstance.addVoter(VOTER1, { from: VOTER1 }),
        "Ownable: caller is not the owner"
      );
    });

    it("should send even when registering voter", async () => {
      const _event = await votingInstance.addVoter(VOTER2);
      expectEvent(_event, "VoterRegistered");
    });

    it("refuse to register a same voter twice", async () => {
      await expectRevert(
        votingInstance.addVoter(VOTER2, { from: OWNER }),
        "Already registered"
      );
    });

    it("emit event when calling startProposalsRegistering", async () => {
      const event = await votingInstance.startProposalsRegistering();
      expectEvent(event, "WorkflowStatusChange", {
        previousStatus: new BN(Voting.WorkflowStatus.RegisteringVoters),
        newStatus: new BN(Voting.WorkflowStatus.ProposalsRegistrationStarted),
      });
    });
  });

  describe("Test proposals registering", async () => {
    before(async () => {
      await setupForStatus(Voting.WorkflowStatus.ProposalsRegistrationStarted);
    });

    const _desc = "My proposal description";

    it("register a proposal from a registered user", async () => {
      await votingInstance.addProposal(_desc, { from: VOTER1 });
      const proposal = await votingInstance.getOneProposal(0, { from: VOTER1 });
      expect(proposal.description).to.be.equal(_desc);
    });

    it("non-voter cannot register a proposal", async () => {
      await expectRevert(
        votingInstance.addProposal("description", {
          from: UNREGISTEREDACCOUNT,
        }),
        "You're not a voter"
      );
    });

    it("emit event when regitering a proposal", async () => {
      const event = await votingInstance.addProposal("autre description", {
        from: VOTER2,
      });
      expectEvent(event, "ProposalRegistered", { proposalId: new BN(1) });
    });

    it("refuse a null proposal", async () => {
      await expectRevert(
        votingInstance.addProposal("", {
          from: VOTER1,
        }),
        "Vous ne pouvez pas ne rien proposer"
      );
    });

    it("only owner can stop proposal registrations", async () => {
      await expectRevert(
        votingInstance.endProposalsRegistering({ from: VOTER1 }),
        "Ownable: caller is not the owner"
      );
    });

    it("emit event when stoping proposal registrations", async () => {
      const ev = await votingInstance.endProposalsRegistering();
      expectEvent(ev, "WorkflowStatusChange", {
        previousStatus: new BN(
          Voting.WorkflowStatus.ProposalsRegistrationStarted
        ),
        newStatus: new BN(Voting.WorkflowStatus.ProposalsRegistrationEnded),
      });
    });
  });

  describe("Tests setVote", async () => {
    before(async () => {
      await setupForStatus(Voting.WorkflowStatus.ProposalsRegistrationEnded);
    });

    it("cannot vote before voting session has started", async () => {
      await expectRevert(
        votingInstance.setVote(1, { from: VOTER1 }),
        "Voting session havent started yet"
      );
    });

    it("register a vote", async () => {
      await votingInstance.startVotingSession();
      await votingInstance.setVote(new BN(0), { from: VOTER1 });
      const prop0 = await votingInstance.getOneProposal(0, { from: VOTER1 });
      expect(new BN(prop0.voteCount)).to.be.bignumber.equal(new BN(1));
    });

    it("same user cannot vote twice", async () => {
      await expectRevert(
        votingInstance.setVote(2, { from: VOTER1 }),
        "You have already voted"
      );
    });

    it("cannot vote for an unexisting proposal", async () => {
      await expectRevert(
        votingInstance.setVote(200, { from: VOTER2 }),
        "Proposal not found"
      );
    });

    it("emit event after voting", async () => {
      const event = await votingInstance.setVote(1, { from: VOTER2 });
      expectEvent(event, "Voted", { voter: VOTER2, proposalId: new BN(1) });
    });

    it("non-voter cannot vote", async () => {
      await expectRevert(
        votingInstance.setVote(1, { from: UNREGISTEREDACCOUNT }),
        "You're not a voter"
      );
    });
  });

  describe("end votes", async () => {
    before(async () => {
      await setupForStatus(Voting.WorkflowStatus.VotingSessionStarted);
    });

    it("only owner can end votes", async () => {
      await expectRevert(
        votingInstance.endVotingSession({ from: VOTER4 }),
        "Ownable: caller is not the owner"
      );
    });

    it("emit event when ending voting session", async () => {
      const event = await votingInstance.endVotingSession();
      expectEvent(event, "WorkflowStatusChange");
    });

    it("cannot return to previous workflow state", async () => {
      expectRevert(
        votingInstance.startVotingSession(),
        "Registering proposals phase is not finished"
      );
    });
  });

  describe("Tally votes", async () => {
    beforeEach(async () => {
      await setupForStatus(Voting.WorkflowStatus.VotingSessionEnded);
    });

    it("only owner can tally votes", async () => {
      await expectRevert(
        votingInstance.tallyVotes({ from: VOTER5 }),
        "Ownable: caller is not the owner"
      );
    });

    it("proposal 1 wins", async () => {
      await votingInstance.tallyVotes();
      const winningId = await votingInstance.winningProposalID.call();
      expect(new BN(winningId)).to.be.bignumber.equal(new BN(1));
    });

    it("emit an event when using tally votes ", async () => {
      const event = await votingInstance.tallyVotes();
      expectEvent(event, "WorkflowStatusChange", {
        previousStatus: new BN(4),
        newStatus: new BN(5),
      });
    });
  });
});

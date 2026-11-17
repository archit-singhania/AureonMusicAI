# Review a shared mix

The project owner opens Studio → Mix listening room, loads the saved mix versions, chooses version A, enters the reviewer's existing Aureon account email, and selects **Share version A for review**. This creates an in-app invitation. The owner can repeat the action for other versions.

The reviewer signs into that account, opens Library → Shared mix reviews, and selects **Load review inbox**. Expand the invitation and audition the shared version. Add a timestamp or range in milliseconds and enter feedback. Both participants can reply, resolve and reopen comments. The invited reviewer can approve the version or request changes with an explanation. A newly rendered version needs its own review.

The owner can revoke the invitation from the same inbox. Refreshing the reviewer inbox removes the revoked item. Each new audio request checks the grant, including requests made with a previously issued audition link. An audition link lasts five minutes. Bytes already delivered to a player can remain buffered or locally saved.

Reviews retain the mix-version ID, reviewer, comments, replies, dispositions and an action history. A revision check rejects concurrent stale edits. The review grant is separate from project membership. The integration journey checks access to the shared audio while the project and underlying asset endpoints deny an invited reviewer access.

Further acceptance includes two interactive Flutter clients, real-device audio behavior and visual inspection of long comment threads on small screens.

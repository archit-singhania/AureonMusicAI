# Mix listening room

In Studio, render a mix and open **Mix listening room**. Choose its completed render, enter a version name, and save. Change a track gain or effect, save the project, render again, and name the second render. A version captures the project settings submitted to its selected job and references that job’s completed master asset.

Choose **Load saved mix versions** when reopening the project, then select the two versions as A and B. Compare them to see the changed parameters. Track and clip changes display their identifiers. Use the original A/B buttons to audition the saved masters. For matched playback, enable loudness matching before comparing. The service queues an audio analysis job. Load the matched previews after processing finishes, then use their individual playback buttons.

Save any current edits before restoring. **Restore A as new project revision** saves the previous project state to history and restores A’s settings. Both named versions and their original audio remain available. A revision conflict requires refreshing the project. Render again to produce a new master from the restored settings.

The integration test rendered two real WAVs with track gains of 0.25 and 0.8. It checked the parameter diff, ownership, selected asset IDs, decoded frame counts, and a level difference under 0.2 dB between the matched tone fixtures. Both original WAVs remained byte-for-byte identical after matching. Restoration rejected an outdated project revision and retained both versions.

The same audio journey passed through the public .NET gateway, along with its four existing transport checks. Version-bound collaborative comments and approvals are documented in COLLABORATIVE-REVIEW.md. Interactive browser acceptance of the listening-room controls and physical playback remain pending.

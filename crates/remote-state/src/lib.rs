//! Remote View state providers.
//!
//! The companion app must only present processed frames while Factorio is in
//! Remote View. Detection is abstracted so a visual marker bootstrap can be
//! replaced by IPC without rewriting the pipeline.

use analog_remote_view_core::Frame;

/// Whether Factorio Remote View is currently active.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum RemoteViewState {
    Active,
    Inactive,
    #[default]
    Unknown,
}

/// Abstraction over Remote View detection mechanisms.
pub trait RemoteViewStateProvider {
    fn state(&self) -> RemoteViewState;

    /// Optional frame inspection hook for marker-based providers.
    fn observe_frame(&mut self, _frame: &Frame) {}
}

/// Always reports unknown — used until Milestone 5 wires the marker.
#[derive(Debug, Default)]
pub struct UnknownRemoteViewState;

impl RemoteViewStateProvider for UnknownRemoteViewState {
    fn state(&self) -> RemoteViewState {
        RemoteViewState::Unknown
    }
}

/// Placeholder for the Milestone 5 visual marker detector.
#[derive(Debug, Default)]
pub struct MarkerRemoteViewState {
    last: RemoteViewState,
}

impl RemoteViewStateProvider for MarkerRemoteViewState {
    fn state(&self) -> RemoteViewState {
        self.last
    }

    fn observe_frame(&mut self, _frame: &Frame) {
        // Milestone 5: sample a known corner pixel / pattern.
    }
}

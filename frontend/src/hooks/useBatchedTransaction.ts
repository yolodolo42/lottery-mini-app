import { useCallback, useState, useEffect, useRef } from "react";
import {
  useSendCalls,
  useCallsStatus,
  useWaitForTransactionReceipt,
  useSendTransaction,
} from "wagmi";
import type { Address } from "viem";
import { encodeFunctionData } from "viem";
import { baseSepolia } from "wagmi/chains";
import { TARGET_CHAIN_ID } from "@/lib/wagmiConfig";

export type Call = {
  to: Address;
  data?: `0x${string}`;
  value?: bigint;
};

type BatchedTransactionState = "idle" | "pending" | "confirming" | "success" | "error";

type UseBatchedTransactionReturn = {
  execute: (calls: Call[]) => Promise<void>;
  state: BatchedTransactionState;
  error: Error | null;
  reset: () => void;
};

/**
 * Hook for executing batched transactions using EIP-5792 when available,
 * with fallback to sequential transactions.
 */
export function useBatchedTransaction(): UseBatchedTransactionReturn {
  const [state, setState] = useState<BatchedTransactionState>("idle");
  const [error, setError] = useState<Error | null>(null);
  const [pendingCalls, setPendingCalls] = useState<Call[] | null>(null);
  const [currentCallIndex, setCurrentCallIndex] = useState(0);

  // EIP-5792 batching
  const {
    sendCalls,
    data: batchId,
    isPending: isBatchPending,
    error: batchError,
    reset: resetBatch,
  } = useSendCalls();

  const { data: callsStatus } = useCallsStatus({
    id: batchId?.id ?? "",
    query: {
      enabled: !!batchId?.id,
      refetchInterval: (query) =>
        query.state.data?.status === "success" || query.state.data?.status === "failure" ? false : 1000,
    },
  });

  // Sequential fallback
  const {
    sendTransaction,
    data: seqTxHash,
    isPending: isSeqPending,
    error: seqError,
    reset: resetSeq,
  } = useSendTransaction();

  const { isLoading: isSeqConfirming, isSuccess: isSeqSuccess, isError: isSeqTxError } =
    useWaitForTransactionReceipt({
      hash: seqTxHash,
      chainId: TARGET_CHAIN_ID,
    });

  // Track if we're in sequential mode
  const isSequentialMode = useRef(false);
  const lastProcessedIndex = useRef(-1);

  // Handle batch status changes
  useEffect(() => {
    if (!batchId?.id) return;

    if (callsStatus?.status === "success") {
      setState("success");
      setPendingCalls(null);
    }
  }, [batchId, callsStatus]);

  // Handle batch errors - fall back to sequential if wallet doesn't support batching
  useEffect(() => {
    if (!batchError) return;

    const errorMessage = batchError.message || String(batchError);
    const isMethodNotSupported =
      errorMessage.includes('wallet_sendCalls') ||
      errorMessage.includes('does not exist') ||
      errorMessage.includes('not available') ||
      errorMessage.includes('not supported') ||
      errorMessage.includes('MethodNotFound') ||
      errorMessage.includes('-32604');

    if (isMethodNotSupported && pendingCalls && pendingCalls.length > 0) {
      // Wallet doesn't support batching, fall back to sequential
      resetBatch();
      isSequentialMode.current = true;
      const firstCall = pendingCalls[0];
      setCurrentCallIndex(0);
      lastProcessedIndex.current = -1;
      sendTransaction({
        to: firstCall.to,
        data: firstCall.data,
        value: firstCall.value ?? 0n,
        chainId: TARGET_CHAIN_ID,
      });
    } else {
      setError(batchError);
      setState("error");
      setPendingCalls(null);
    }
  }, [batchError, pendingCalls, resetBatch, sendTransaction]);

  // Handle sequential transaction completion
  useEffect(() => {
    if (!isSequentialMode.current || !pendingCalls) return;

    if (isSeqSuccess && currentCallIndex !== lastProcessedIndex.current) {
      lastProcessedIndex.current = currentCallIndex;
      const nextIndex = currentCallIndex + 1;

      if (nextIndex >= pendingCalls.length) {
        setState("success");
        setPendingCalls(null);
        isSequentialMode.current = false;
      } else {
        setCurrentCallIndex(nextIndex);
        const nextCall = pendingCalls[nextIndex];
        resetSeq();

        setTimeout(() => {
          sendTransaction({
            to: nextCall.to,
            data: nextCall.data,
            value: nextCall.value ?? 0n,
            chainId: TARGET_CHAIN_ID,
          });
        }, 100);
      }
    }
  }, [isSeqSuccess, currentCallIndex, pendingCalls, sendTransaction, resetSeq]);

  // Handle sequential errors
  useEffect(() => {
    if (seqError || isSeqTxError) {
      setError(seqError || new Error("Transaction failed"));
      setState("error");
      setPendingCalls(null);
      isSequentialMode.current = false;
    }
  }, [seqError, isSeqTxError]);

  // Update state based on pending status
  useEffect(() => {
    if (isBatchPending || isSeqPending) {
      setState("pending");
    } else if (isSeqConfirming) {
      setState("confirming");
    }
  }, [isBatchPending, isSeqPending, isSeqConfirming]);

  const execute = useCallback(
    async (calls: Call[]) => {
      if (calls.length === 0) return;

      setError(null);
      setState("pending");
      setPendingCalls(calls);
      setCurrentCallIndex(0);
      lastProcessedIndex.current = -1;

      // Always try batched sendCalls first
      isSequentialMode.current = false;
      try {
        await sendCalls({
          calls: calls.map((call) => ({
            to: call.to,
            data: call.data,
            value: call.value,
          })),
          chainId: TARGET_CHAIN_ID,
        });
      } catch (err) {
        // If batching fails synchronously, fall back to sequential
        isSequentialMode.current = true;
        const firstCall = calls[0];
        sendTransaction({
          to: firstCall.to,
          data: firstCall.data,
          value: firstCall.value ?? 0n,
          chainId: TARGET_CHAIN_ID,
        });
      }
    },
    [sendCalls, sendTransaction]
  );

  const reset = useCallback(() => {
    setState("idle");
    setError(null);
    setPendingCalls(null);
    setCurrentCallIndex(0);
    lastProcessedIndex.current = -1;
    isSequentialMode.current = false;
    resetBatch();
    resetSeq();
  }, [resetBatch, resetSeq]);

  return {
    execute,
    state,
    error,
    reset,
  };
}

/**
 * Helper to encode an ERC20 approve call
 */
export function encodeApproveCall(
  tokenAddress: Address,
  spender: Address,
  amount: bigint
): Call {
  const data = encodeFunctionData({
    abi: [
      {
        name: "approve",
        type: "function",
        inputs: [
          { name: "spender", type: "address" },
          { name: "amount", type: "uint256" },
        ],
        outputs: [{ type: "bool" }],
      },
    ],
    functionName: "approve",
    args: [spender, amount],
  });

  return {
    to: tokenAddress,
    data,
    value: 0n,
  };
}

/**
 * Helper to encode a contract call
 */
export function encodeContractCall(
  contractAddress: Address,
  abi: readonly unknown[],
  functionName: string,
  args: unknown[],
  value?: bigint
): Call {
  const data = encodeFunctionData({
    abi: abi as any,
    functionName,
    args,
  });

  return {
    to: contractAddress,
    data,
    value: value ?? 0n,
  };
}

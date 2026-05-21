from typing import Any

from pprint import pprint
import ray
from ray.data.llm import build_llm_processor, vLLMEngineProcessorConfig

DATASET_LIMIT = 10_000

path = "https://llm-guide.s3.us-west-2.amazonaws.com/data/ray-data-llm/customers-2000000.csv"

print("Loading dataset from remote URL...")
ds = ray.data.read_csv(path)

print(f"Limiting dataset to {DATASET_LIMIT} rows for initial processing.")
ds_small = ds.limit(DATASET_LIMIT)

# Repartition 2-4x your worker (GPU) count for optimal parallelism.
# 4 GPUs → 8-16 partitions, 10 GPUs → 20-40 partitions.
num_partitions = 128
print(f"Repartitioning dataset into {num_partitions} blocks for parallelism...")
ds_small = ds_small.repartition(num_blocks=num_partitions)

processor_config = vLLMEngineProcessorConfig(
    model_source="unsloth/Llama-3.1-8B-Instruct",
    engine_kwargs=dict(
        max_model_len=256,
    ),
    batch_size=256,
    accelerator_type="L4",
    concurrency=4,
)

CHOICES = [
    "Law Firm",
    "Healthcare",
    "Technology",
    "Retail",
    "Consulting",
    "Manufacturing",
    "Finance",
    "Real Estate",
    "Other",
]

def preprocess(row: dict[str, Any]) -> dict[str, Any]:
    return dict(
        messages=[
            {
                "role": "system",
                "content": "You are a helpful assistant that infers company industries. "
                           "Based on the company name provided, output only the industry category. "
                           f"Choose from: {', '.join(CHOICES)}."
            },
            {
                "role": "user",
                "content": f"What industry is this company in: {row['Company']}"
            },
        ],
        sampling_params=dict(
            temperature=0,
            max_tokens=16,
            structured_outputs=dict(choice=CHOICES),
        ),
    )

def postprocess(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "inferred_industry": row["generated_text"],
        **row,
    }

processor = build_llm_processor(
    processor_config,
    preprocess=preprocess,
    postprocess=postprocess,
)

processed_small = processor(ds_small)
processed_small = processed_small.materialize()

print(f"\nProcessed {processed_small.count()} rows successfully.")
sampled = processed_small.take(3)
print("\n==================GENERATED OUTPUT===============\n")
pprint(sampled)

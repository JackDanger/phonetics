from torch.nn.utils.rnn import pad_sequence
from torch.utils.data import DataLoader, Dataset
from torchtext.vocab import build_vocab_from_iterator
from tqdm import tqdm
import torch
import torch.nn as nn
import torch.optim as optim
import unicodedata

# Helper function to normalize text
def unicode_to_ascii(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s)
                   if unicodedata.category(c) != 'Mn')

# Tokenization
def tokenize(text):
    text = unicode_to_ascii(text.lower().strip())
    return list(text)

# Dataset class
class TextIPAData(Dataset):
    def __init__(self, file_path, vocab):
        self.pairs = self.read_data(file_path)
        self.vocab = vocab

    def read_data(self, file_path):
        with open(file_path, encoding='utf-8') as f:
            lines = f.read().strip().split('\n')
        pairs = [line.split(' ') for line in lines]
        return pairs

    def __len__(self):
        return len(self.pairs)

    def __getitem__(self, idx):
        src_line, tgt_line = self.pairs[idx]
        src_tensor = torch.tensor([self.vocab[token] for token in tokenize(src_line)], dtype=torch.long)
        tgt_tensor = torch.tensor([self.vocab[token] for token in tokenize(tgt_line)], dtype=torch.long)
        return src_tensor, tgt_tensor


# Define constants
BATCH_SIZE = 128
# We'll do the ipa_to_text later, maybe in one model but maybe separately
SRC_FILE_PATH = 'text_to_ipa.txt'

# Build vocabularies
def yield_tokens(file):
    with open(file, 'r', encoding='utf-8') as f:
        for line in f:
            src, tgt = line.strip().split(' ')
            yield tokenize(src)
            yield tokenize(tgt)
vocab = build_vocab_from_iterator(yield_tokens(SRC_FILE_PATH), specials=["<unk>", "<pad>", "<sos>", "<eos>"])


# Define dataset and dataloader
src_dataset = TextIPAData(SRC_FILE_PATH, vocab)

def collate_batch(batch):
    src_batch, tgt_batch = zip(*batch)  # This separates the source and target tensors

    src_padded = pad_sequence(src_batch, padding_value=vocab['<pad>'])
    tgt_padded = pad_sequence(tgt_batch, padding_value=vocab['<pad>'])

    src_mask = (src_padded == vocab['<pad>']).transpose(0, 1)
    tgt_mask = (tgt_padded == vocab['<pad>']).transpose(0, 1)


    return src_padded, tgt_padded, src_mask, tgt_mask

src_loader = DataLoader(src_dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_batch)

# Transformer Model
class TransformerModel(nn.Module):
    def __init__(self, input_dim, output_dim, emb_dim, n_heads, ff_dim, num_layers, dropout, max_length=100):
        super(TransformerModel, self).__init__()
        self.src_tok_emb = nn.Embedding(input_dim, emb_dim)
        self.tgt_tok_emb = nn.Embedding(output_dim, emb_dim)
        self.positional_encoding = nn.Parameter(torch.zeros(max_length, emb_dim))
        self.transformer = nn.Transformer(emb_dim, n_heads, num_layers, num_layers, ff_dim, dropout)
        self.fc_out = nn.Linear(emb_dim, output_dim)
        self.dropout = nn.Dropout(dropout)
        self.src_pad_idx = input_dim - 1
        self.tgt_pad_idx = output_dim - 1

    def forward(self, src, tgt, src_key_padding_mask, tgt_key_padding_mask):
        src_seq_length, N = src.shape
        tgt_seq_length, N = tgt.shape
        src_max_seq = len(src)
        tgt_max_seq = len(tgt)

        src_emb = self.src_tok_emb(src)
        tgt_emb = self.tgt_tok_emb(tgt)

        # Apply positional encoding correctly
        src_emb += self.positional_encoding[:src_seq_length, :].unsqueeze(1).expand(-1, N, -1)
        tgt_emb += self.positional_encoding[:tgt_seq_length, :].unsqueeze(1).expand(-1, N, -1)

        src_emb = self.dropout(src_emb)
        tgt_emb = self.dropout(tgt_emb)

        output = self.transformer(src_emb, tgt_emb,
                                  src_key_padding_mask=src_key_padding_mask,
                                  tgt_key_padding_mask=tgt_key_padding_mask,
                                  memory_key_padding_mask=src_key_padding_mask)

        return self.fc_out(output)

# Training loop
def train(model, loader, optimizer, criterion, clip):
    model.train()
    epoch_loss = 0
    for i, data in enumerate(tqdm(loader)):
        src, tgt, src_mask, tgt_mask = data
        src, tgt = src.to(device), tgt.to(device)
        src_mask, tgt_mask = src_mask.to(device), tgt_mask.to(device)
        optimizer.zero_grad()

        output = model(src, tgt, src_mask, tgt_mask)
        output_dim = output.shape[-1]
        output = output.reshape(-1, output_dim)
        tgt = tgt.reshape(-1)

        loss = criterion(output, tgt)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), clip)
        optimizer.step()
        epoch_loss += loss.item()
    return epoch_loss / len(loader)

# Define the device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"device: {device}")

# Define model, optimizer, and loss function
model = TransformerModel(len(vocab), len(vocab), emb_dim=256, n_heads=8, ff_dim=512, num_layers=3, dropout=0.1).to(device)
optimizer = optim.Adam(model.parameters(), lr=0.0001)
criterion = nn.CrossEntropyLoss(ignore_index=vocab['<pad>'])

# Example of training the model
train_loss = train(model, src_loader, optimizer, criterion, clip=1)

# Save model
torch.save(model.state_dict(), 'transformer_model.pth')

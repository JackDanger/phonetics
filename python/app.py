import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, Dataset
from torch.nn.utils.rnn import pad_sequence
from torchtext.vocab import build_vocab_from_iterator
import unicodedata

# Helper function to normalize text
def unicode_to_ascii(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s)
                   if unicodedata.category(c) != 'Mn')

# Tokenization
def tokenize(text, token_type="char"):
    text = unicode_to_ascii(text.lower().strip())
    if token_type == "char":
        return list(text)
    else:
        return text.split()

# Dataset class
class TextIPAData(Dataset):
    def __init__(self, file_path, src_vocab, tgt_vocab, token_type="char"):
        self.pairs = self.read_data(file_path)
        self.src_vocab = src_vocab
        self.tgt_vocab = tgt_vocab
        self.token_type = token_type

    def read_data(self, file_path):
        with open(file_path, encoding='utf-8') as f:
            lines = f.read().strip().split('\n')
        pairs = [line.split(' ') for line in lines]
        return pairs

    def __len__(self):
        return len(self.pairs)

    def __getitem__(self, idx):
        src_line, tgt_line = self.pairs[idx]
        src_tensor = torch.tensor([self.src_vocab[token] for token in tokenize(src_line, self.token_type)], dtype=torch.long)
        tgt_tensor = torch.tensor([self.tgt_vocab[token] for token in tokenize(tgt_line, self.token_type)], dtype=torch.long)
        return src_tensor, tgt_tensor

# Function to create vocabularies
def build_vocab(data_file, token_type="char"):
    def yield_tokens(data_file):
        with open(data_file, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    src, tgt = line.strip().split(' ')
                except:
                    print(line)
                yield tokenize(src, token_type)
                yield tokenize(tgt, token_type)
    return build_vocab_from_iterator(yield_tokens(data_file), specials=["<unk>", "<pad>", "<sos>", "<eos>"])

# Define constants
BATCH_SIZE = 64
SRC_FILE_PATH = 'text_to_ipa.txt'
TGT_FILE_PATH = 'ipa_to_text.txt'

# Build vocabularies
src_vocab = build_vocab(SRC_FILE_PATH)
tgt_vocab = build_vocab(TGT_FILE_PATH)

# Define dataset and dataloader
src_dataset = TextIPAData(SRC_FILE_PATH, src_vocab, tgt_vocab)
tgt_dataset = TextIPAData(TGT_FILE_PATH, tgt_vocab, src_vocab)

def collate_batch(batch):
    src_batch, tgt_batch = zip(*batch)  # This separates the source and target tensors
    src_padded = pad_sequence(src_batch, padding_value=src_vocab['<pad>'])
    tgt_padded = pad_sequence(tgt_batch, padding_value=tgt_vocab['<pad>'])
    return src_padded, tgt_padded

src_loader = DataLoader(src_dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_batch)
tgt_loader = DataLoader(tgt_dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_batch)

# Transformer Model
class TransformerModel(nn.Module):
    def __init__(self, input_dim, output_dim, emb_dim, n_heads, ff_dim, num_layers, dropout, max_length=100):
        super(TransformerModel, self).__init__()
        self.src_tok_emb = nn.Embedding(input_dim, emb_dim)
        self.tgt_tok_emb = nn.Embedding(output_dim, emb_dim)
        self.positional_encoding = nn.Parameter(torch.zeros(1, max_length, emb_dim))
        self.transformer = nn.Transformer(emb_dim, n_heads, num_layers, num_layers, ff_dim, dropout)
        self.fc_out = nn.Linear(emb_dim, output_dim)
        self.dropout = nn.Dropout(dropout)
        self.src_pad_idx = input_dim - 1
        self.tgt_pad_idx = output_dim - 1

    def make_src_mask(self, src):
        src_mask = src.transpose(0, 1) == self.src_pad_idx
        return src_mask

    def forward(self, src, tgt):
        src_seq_length, N = src.shape
        tgt_seq_length, N = tgt.shape

        src_positions = torch.arange(0, src_seq_length).unsqueeze(1).expand(src_seq_length, N).to(src.device)
        tgt_positions = torch.arange(0, tgt_seq_length).unsqueeze(1).expand(tgt_seq_length, N).to(tgt.device)

        src_emb = self.dropout((self.src_tok_emb(src) + self.positional_encoding[:,:src_seq_length]))
        tgt_emb = self.dropout((self.tgt_tok_emb(tgt) + self.positional_encoding[:,:tgt_seq_length]))

        src_mask = self.make_src_mask(src)
        tgt_mask = self.transformer.generate_square_subsequent_mask(tgt_seq_length).to(tgt.device)

        output = self.transformer(src_emb, tgt_emb, src_key_padding_mask=src_mask, tgt_key_padding_mask=src_mask, memory_key_padding_mask=src_mask)
        return self.fc_out(output)

# Training loop
def train(model, loader, optimizer, criterion, clip):
    model.train()
    epoch_loss = 0
    for src, trg in loader:
        src, trg = src.to(device), trg.to(device)
        optimizer.zero_grad()
        output = model(src, trg[:-1, :])
        output_dim = output.shape[-1]
        output = output.reshape(-1, output_dim)
        trg = trg[1:].reshape(-1)
        loss = criterion(output, trg)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), clip)
        optimizer.step()
        epoch_loss += loss.item()
    return epoch_loss / len(loader)

# Define the device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Define model, optimizer, and loss function
model = TransformerModel(len(src_vocab), len(tgt_vocab), emb_dim=256, n_heads=8, ff_dim=512, num_layers=3, dropout=0.1).to(device)
optimizer = optim.Adam(model.parameters(), lr=0.0001)
criterion = nn.CrossEntropyLoss(ignore_index=tgt_vocab['<pad>'])

# Example of training the model
train_loss = train(model, src_loader, optimizer, criterion, clip=1)
print(f'Training Loss: {train_loss}')

# Save model
torch.save(model.state_dict(), 'transformer_model.pth')
